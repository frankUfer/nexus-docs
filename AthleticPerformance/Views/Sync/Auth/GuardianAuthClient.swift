import Foundation

/// Communicates with Guardian (nexus-gate) for device authentication.
/// Handles POST /auth/token and GET /health.
actor GuardianAuthClient {

    // MARK: - Response Types

    struct TokenResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
        }
    }

    struct HealthResponse: Decodable {
        let status: String
        let service: String
    }

    // MARK: - Errors

    enum AuthError: Error {
        case noGuardianURL
        case noCredentials
        case authenticationFailed(String)
        case deviceDeactivated
        case validationError
        case rateLimited(retryAfter: TimeInterval?)
        case networkError(String)
        case unexpectedResponse(Int)
    }

    // MARK: - Properties

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Authenticate

    /// Request a JWT from Guardian via POST /auth/token.
    func authenticate(deviceId: UUID, password: String, guardianURL: URL) async throws -> TokenResponse {
        let url = guardianURL.appendingPathComponent("auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: String] = [
            "device_id": deviceId.uuidString,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unexpectedResponse(0)
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(TokenResponse.self, from: data)

        case 401:
            let detail = parseDetail(from: data)
            if detail?.localizedCaseInsensitiveContains("deactivated") == true {
                throw AuthError.deviceDeactivated
            }
            throw AuthError.authenticationFailed(detail ?? "Authentication failed")

        case 422:
            throw AuthError.validationError

        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init)
            throw AuthError.rateLimited(retryAfter: retryAfter)

        default:
            throw AuthError.unexpectedResponse(http.statusCode)
        }
    }

    // MARK: - Health Check (VPN connectivity probe)

    /// Check Guardian /health — no auth required. Returns true if VPN is reachable.
    func checkHealth(guardianURL: URL) async -> Bool {
        let url = guardianURL.appendingPathComponent("health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            return health.status == "ok"
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func parseDetail(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["detail"] as? String
    }
}

// MARK: - Localized Error Descriptions

extension GuardianAuthClient.AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noGuardianURL:
            return "Guardian URL not configured"
        case .noCredentials:
            return "Device password not set"
        case .authenticationFailed(let detail):
            return "Authentication failed: \(detail)"
        case .deviceDeactivated:
            return "Device has been deactivated by administrator"
        case .validationError:
            return "Invalid authentication request"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited — retry in \(Int(seconds / 60)) minutes"
            }
            return "Rate limited — try again later"
        case .networkError(let detail):
            return detail
        case .unexpectedResponse(let code):
            return "Unexpected response (\(code))"
        }
    }
}
