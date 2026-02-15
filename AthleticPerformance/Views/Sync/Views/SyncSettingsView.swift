import SwiftUI

/// Sync settings: server URLs, device identity, Guardian authentication, connection test.
struct SyncSettingsView: View {
    @EnvironmentObject var deviceConfigStore: DeviceConfigStore
    @EnvironmentObject var authManager: AuthManager

    @State private var serverURL: String = ""
    @State private var guardianURL: String = ""
    @State private var deviceName: String = ""
    @State private var deviceIdInput: String = ""
    @State private var passwordInput: String = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            serverSection
            deviceSection
            authSection
            connectionSection
            saveSection
        }
        .navigationTitle(NSLocalizedString("syncSettingsTitle", comment: "Sync Settings"))
        .onAppear { loadFields() }
    }

    // MARK: - Server Configuration

    private var serverSection: some View {
        Section(NSLocalizedString("syncServerConfig", comment: "Server Configuration")) {
            TextField(NSLocalizedString("syncServerURL", comment: "nexus-core URL"), text: $serverURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { saveServerURL() }

            TextField(NSLocalizedString("syncGuardianURL", comment: "Guardian URL"), text: $guardianURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { saveGuardianURL() }

            TextField(NSLocalizedString("syncDeviceName", comment: "Device Name"), text: $deviceName)
                .onSubmit { saveDeviceName() }
        }
    }

    // MARK: - Device Identity

    private var deviceSection: some View {
        Section(NSLocalizedString("syncDeviceInfo", comment: "Device Identity")) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("syncDeviceId", comment: "Device ID"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("UUID", text: $deviceIdInput)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { saveDeviceId() }
            }

            HStack {
                Text(NSLocalizedString("syncRegistered", comment: "Registered"))
                Spacer()
                Image(systemName: deviceConfigStore.config.isRegistered ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(deviceConfigStore.config.isRegistered ? .green : .red)
            }
        }
    }

    // MARK: - Authentication

    private var authSection: some View {
        Section(NSLocalizedString("syncAuthentication", comment: "Authentication")) {
            // Auth status
            HStack {
                Text(NSLocalizedString("syncAuthStatus", comment: "Status"))
                Spacer()
                authStatusBadge
            }

            // Token expiry
            if case .authenticated(let expiresAt) = authManager.status {
                HStack {
                    Text(NSLocalizedString("syncTokenExpires", comment: "Token Expires"))
                    Spacer()
                    Text(expiresAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Rate limit warning
            if case .rateLimited(let retryAfter) = authManager.status {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(NSLocalizedString("syncRateLimited", comment: "Rate limited — retry after"))
                    Text(retryAfter, style: .relative)
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }

            // Device password
            SecureField(NSLocalizedString("syncDevicePassword", comment: "Device Password"), text: $passwordInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Button(NSLocalizedString("syncSavePassword", comment: "Save Password")) {
                    guard !passwordInput.isEmpty else { return }
                    _ = KeychainHelper.saveDevicePassword(passwordInput)
                    passwordInput = ""
                    authManager.updateStatus()
                }
                .disabled(passwordInput.isEmpty)

                Spacer()

                Button(NSLocalizedString("syncClearCredentials", comment: "Clear Credentials"), role: .destructive) {
                    authManager.clearAll()
                }
            }

            // Authenticate button
            Button {
                Task { await authManager.authenticate() }
            } label: {
                HStack {
                    if case .authenticating = authManager.status {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Label(NSLocalizedString("syncAuthenticate", comment: "Authenticate"), systemImage: "lock.shield")
                }
            }
            .disabled(!authManager.isConfigured || authManager.status == .authenticating)
        }
    }

    // MARK: - Auth Status Badge

    @ViewBuilder
    private var authStatusBadge: some View {
        switch authManager.status {
        case .unconfigured:
            Label(NSLocalizedString("syncStatusUnconfigured", comment: "Not configured"), systemImage: "gear.badge.xmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unauthenticated:
            Label(NSLocalizedString("syncStatusUnauthenticated", comment: "Not authenticated"), systemImage: "lock.open")
                .font(.caption)
                .foregroundStyle(.orange)
        case .authenticating:
            Label(NSLocalizedString("syncStatusAuthenticating", comment: "Authenticating..."), systemImage: "lock.rotation")
                .font(.caption)
                .foregroundStyle(.blue)
        case .authenticated:
            Label(NSLocalizedString("syncStatusAuthenticated", comment: "Authenticated"), systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .rateLimited:
            Label(NSLocalizedString("syncStatusRateLimited", comment: "Rate limited"), systemImage: "hand.raised.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    // MARK: - Connection Test

    private var connectionSection: some View {
        Section(NSLocalizedString("syncTestConnection", comment: "Connection Test")) {
            Button {
                testConnection()
            } label: {
                if isTesting {
                    ProgressView()
                } else {
                    Label(NSLocalizedString("syncTestButton", comment: "Test Connection"), systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .disabled(isTesting || guardianURL.isEmpty)

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("Server OK") ? .green : .orange)
            }
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        Section {
            Button(NSLocalizedString("syncSaveSettings", comment: "Save Settings")) {
                saveAll()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func loadFields() {
        serverURL = deviceConfigStore.config.serverURL
        guardianURL = deviceConfigStore.config.guardianURL
        deviceName = deviceConfigStore.config.deviceName
        deviceIdInput = deviceConfigStore.config.deviceId.uuidString
    }

    private func saveServerURL() {
        deviceConfigStore.config.serverURL = serverURL
        deviceConfigStore.save()
    }

    private func saveGuardianURL() {
        deviceConfigStore.config.guardianURL = guardianURL
        deviceConfigStore.save()
        authManager.updateStatus()
    }

    private func saveDeviceName() {
        deviceConfigStore.config.deviceName = deviceName
        deviceConfigStore.save()
    }

    private func saveDeviceId() {
        guard let uuid = UUID(uuidString: deviceIdInput) else { return }
        deviceConfigStore.config.deviceId = uuid
        deviceConfigStore.save()
    }

    private func saveAll() {
        saveServerURL()
        saveGuardianURL()
        saveDeviceName()
        saveDeviceId()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            var results: [String] = []

            // 1. VPN check via Guardian /health
            await authManager.checkVPNConnectivity()
            if authManager.isVPNReachable {
                results.append("VPN OK")
            } else {
                results.append("VPN not reachable — check WireGuard")
                testResult = results.joined(separator: "\n")
                isTesting = false
                return
            }

            // 2. Auth check
            do {
                _ = try await authManager.ensureValidToken()
                results.append("Auth OK")
            } catch {
                results.append("Auth failed: \(error.localizedDescription)")
                testResult = results.joined(separator: "\n")
                isTesting = false
                return
            }

            // 3. nexus-core server check
            let client = NexusSyncClient(deviceConfigStore: deviceConfigStore, authManager: authManager)
            do {
                let response = try await client.status()
                results.append("Server OK — v\(response.currentVersion)")
            } catch {
                results.append("Server error: \(error.localizedDescription)")
            }

            testResult = results.joined(separator: "\n")
            isTesting = false
        }
    }
}
