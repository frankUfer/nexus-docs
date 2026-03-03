import Foundation

/// Response from the provisioning claim endpoint.
struct ClaimResponse: Codable {
    let deviceId: String
    let deviceName: String
    let serverUrl: String
    let deploymentTier: String
    let guardianUrl: String?
    let vpnIp: String?
    let password: String?
    let wireguardConfig: String?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
        case serverUrl = "server_url"
        case deploymentTier = "deployment_tier"
        case guardianUrl = "guardian_url"
        case vpnIp = "vpn_ip"
        case password
        case wireguardConfig = "wireguard_config"
    }
}

enum OnboardingError: Error, LocalizedError {
    case noServer
    case invalidCode(String)
    case networkError(Error)
    case serverError(statusCode: Int, detail: String?)

    var errorDescription: String? {
        switch self {
        case .noServer:
            return "No Nexus server found. Connect via USB cable."
        case .invalidCode(let msg):
            return msg
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .serverError(_, let detail):
            return detail ?? "Server error"
        }
    }
}

/// Client for the provisioning API during iPad onboarding (ADR-005).
actor OnboardingClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Claim a setup code from the discovered Nexus server.
    func claim(code: String, wgPublicKey: String?, serverBaseURL: String) async throws -> ClaimResponse {
        guard let url = URL(string: "\(serverBaseURL)/api/v1/provision/claim") else {
            throw OnboardingError.noServer
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Server may call Guardian (10s timeout) during full-tier provisioning,
        // so allow enough headroom for the full server-side chain to complete.
        request.timeoutInterval = 30

        var body: [String: Any] = ["code": code]
        if let key = wgPublicKey {
            body["wg_public_key"] = key
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OnboardingError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(ClaimResponse.self, from: data)
        case 400:
            let detail = parseErrorDetail(data)
            throw OnboardingError.invalidCode(detail ?? "Invalid setup code")
        case 403:
            throw OnboardingError.invalidCode("Provisioning requires a wired (USB) connection")
        default:
            let detail = parseErrorDetail(data)
            throw OnboardingError.serverError(statusCode: http.statusCode, detail: detail)
        }
    }

    private func parseErrorDetail(_ data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["detail"] as? String
        }
        return nil
    }
}
