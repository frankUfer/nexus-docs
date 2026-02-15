import Foundation
import Combine
import os.log

/// Manages the Guardian authentication lifecycle:
/// VPN connectivity check, token acquisition, proactive refresh at 80% lifetime,
/// rate limit handling, and re-authentication on 401 from nexus-core.
@MainActor
final class AuthManager: ObservableObject {

    // MARK: - Published State

    enum AuthStatus: Equatable {
        case unconfigured
        case unauthenticated
        case authenticating
        case authenticated(expiresAt: Date)
        case rateLimited(retryAfter: Date)
        case failed(String)
    }

    @Published private(set) var status: AuthStatus = .unconfigured
    @Published private(set) var isVPNReachable = false

    // MARK: - Dependencies

    private let deviceConfigStore: DeviceConfigStore
    private let guardianClient: GuardianAuthClient
    private let logger = Logger(subsystem: "com.athletic-performance", category: "Auth")

    // MARK: - Internal State

    private var tokenMetadata: TokenMetadata?
    /// Prevents hammering Guardian after repeated failures.
    private var lastFailedAuth: Date?
    private let failedAuthCooldown: TimeInterval = 60

    // MARK: - Init

    init(deviceConfigStore: DeviceConfigStore, guardianClient: GuardianAuthClient = GuardianAuthClient()) {
        self.deviceConfigStore = deviceConfigStore
        self.guardianClient = guardianClient
        restoreState()
    }

    /// Restore auth state from Keychain on launch.
    private func restoreState() {
        if let metadata = KeychainHelper.loadTokenMetadata(),
           KeychainHelper.loadToken() != nil {
            if metadata.isExpired {
                KeychainHelper.deleteToken()
                KeychainHelper.deleteTokenMetadata()
                status = hasCredentials ? .unauthenticated : .unconfigured
            } else {
                tokenMetadata = metadata
                status = .authenticated(expiresAt: metadata.expiresAt)
            }
        } else {
            status = hasCredentials ? .unauthenticated : .unconfigured
        }
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        guardianURL != nil && hasCredentials
    }

    private var hasCredentials: Bool {
        KeychainHelper.loadDevicePassword() != nil
    }

    private var guardianURL: URL? {
        let urlString = deviceConfigStore.config.guardianURL
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
        return url
    }

    // MARK: - Ensure Valid Token

    /// Returns a valid JWT token, authenticating or refreshing as needed.
    /// Call this before every nexus-core API request.
    func ensureValidToken() async throws -> String {
        // Honour rate limit
        if case .rateLimited(let retryAfter) = status {
            guard Date() >= retryAfter else {
                throw GuardianAuthClient.AuthError.rateLimited(
                    retryAfter: retryAfter.timeIntervalSinceNow
                )
            }
            status = .unauthenticated
        }

        // Client-side cooldown after repeated failures
        if let lastFailed = lastFailedAuth,
           Date().timeIntervalSince(lastFailed) < failedAuthCooldown {
            // If we have a still-valid token, use it despite the recent failure
            if let token = KeychainHelper.loadToken(),
               let metadata = tokenMetadata,
               !metadata.isExpired {
                return token
            }
            throw GuardianAuthClient.AuthError.authenticationFailed(
                "Authentication recently failed — waiting to retry"
            )
        }

        // Check existing token
        if let token = KeychainHelper.loadToken(),
           let metadata = tokenMetadata,
           !metadata.isExpired {
            // Token valid — proactively refresh if past 80% lifetime
            if metadata.needsRefresh {
                do {
                    return try await performAuthentication()
                } catch {
                    // Refresh failed but current token is still valid (AUTH_PROTOCOL §Proactive Re-authentication)
                    logger.warning("Proactive refresh failed, using existing token: \(error.localizedDescription)")
                    return token
                }
            }
            return token
        }

        // No valid token — must authenticate
        return try await performAuthentication()
    }

    // MARK: - Re-authenticate (called on 401 from nexus-core)

    /// Clears the current token and re-authenticates with Guardian.
    /// Returns the new JWT token.
    func reauthenticate() async throws -> String {
        KeychainHelper.deleteToken()
        KeychainHelper.deleteTokenMetadata()
        tokenMetadata = nil
        return try await performAuthentication()
    }

    // MARK: - Manual Authenticate (from UI)

    func authenticate() async {
        do {
            _ = try await performAuthentication()
        } catch {
            logger.error("Manual authentication failed: \(error.localizedDescription)")
        }
    }

    // MARK: - VPN Connectivity

    func checkVPNConnectivity() async {
        guard let url = guardianURL else {
            isVPNReachable = false
            return
        }
        isVPNReachable = await guardianClient.checkHealth(guardianURL: url)
    }

    // MARK: - Credential Management

    func updateStatus() {
        if case .authenticated = status { return }
        status = isConfigured ? .unauthenticated : .unconfigured
    }

    func clearToken() {
        KeychainHelper.deleteToken()
        KeychainHelper.deleteTokenMetadata()
        tokenMetadata = nil
        lastFailedAuth = nil
        status = hasCredentials ? .unauthenticated : .unconfigured
    }

    func clearAll() {
        KeychainHelper.deleteToken()
        KeychainHelper.deleteTokenMetadata()
        KeychainHelper.deleteDevicePassword()
        tokenMetadata = nil
        lastFailedAuth = nil
        status = .unconfigured
    }

    // MARK: - Core Authentication

    private func performAuthentication() async throws -> String {
        guard let url = guardianURL else {
            status = .unconfigured
            throw GuardianAuthClient.AuthError.noGuardianURL
        }

        guard let password = KeychainHelper.loadDevicePassword() else {
            status = .unconfigured
            throw GuardianAuthClient.AuthError.noCredentials
        }

        let deviceId = deviceConfigStore.config.deviceId
        status = .authenticating

        do {
            // Check VPN first
            let vpnOk = await guardianClient.checkHealth(guardianURL: url)
            isVPNReachable = vpnOk
            if !vpnOk {
                status = .failed("VPN not reachable")
                lastFailedAuth = Date()
                throw GuardianAuthClient.AuthError.networkError(
                    "Guardian not reachable — check WireGuard connection"
                )
            }

            let response = try await guardianClient.authenticate(
                deviceId: deviceId,
                password: password,
                guardianURL: url
            )

            // Store token + metadata
            let metadata = TokenMetadata(
                obtainedAt: Date(),
                expiresIn: TimeInterval(response.expiresIn)
            )
            _ = KeychainHelper.saveToken(response.accessToken)
            _ = KeychainHelper.saveTokenMetadata(metadata)
            tokenMetadata = metadata
            lastFailedAuth = nil

            status = .authenticated(expiresAt: metadata.expiresAt)
            logger.info("Authenticated, token expires in \(response.expiresIn)s")
            return response.accessToken

        } catch let error as GuardianAuthClient.AuthError {
            switch error {
            case .rateLimited(let retryAfter):
                let retryDate = Date().addingTimeInterval(retryAfter ?? 1800)
                status = .rateLimited(retryAfter: retryDate)
                logger.warning("Rate limited until \(retryDate)")

            case .deviceDeactivated:
                status = .failed("Device is deactivated")
                lastFailedAuth = Date()

            case .authenticationFailed(let detail):
                status = .failed(detail)
                lastFailedAuth = Date()

            default:
                status = .failed(error.localizedDescription)
                lastFailedAuth = Date()
            }
            throw error
        }
    }
}
