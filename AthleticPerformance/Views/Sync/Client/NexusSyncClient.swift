import Foundation

enum SyncClientError: Error {
    case noServerURL
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, body: String?)
    case networkError(Error)
    case decodingError(Error)
}

actor NexusSyncClient {
    private let session: URLSession
    private let deviceConfigStore: DeviceConfigStore
    private let authManager: AuthManager

    private let decoder = JSONDecoder.syncDecoder
    private let encoder = JSONEncoder.syncEncoder

    init(deviceConfigStore: DeviceConfigStore, authManager: AuthManager, session: URLSession = .shared) {
        self.deviceConfigStore = deviceConfigStore
        self.authManager = authManager
        self.session = session
    }

    // MARK: - Push

    func push(_ request: SyncPushRequest) async throws -> SyncPushResponse {
        let url = try await baseURL().appendingPathComponent("sync/push")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)
        return try await performWithAuth(urlRequest)
    }

    // MARK: - Pull

    func pull(sinceVersion: Int, limit: Int = 500) async throws -> SyncPullResponse {
        var components = URLComponents(url: try await baseURL().appendingPathComponent("sync/pull"), resolvingAgainstBaseURL: false)!
        let deviceId = await deviceConfigStore.config.deviceId
        components.queryItems = [
            URLQueryItem(name: "device_id", value: deviceId.uuidString),
            URLQueryItem(name: "since_version", value: String(sinceVersion)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "GET"
        return try await performWithAuth(urlRequest)
    }

    // MARK: - Upload

    func upload(token: String, fileData: Data, filename: String, contentType: String) async throws -> SyncUploadResponse {
        let url = try await baseURL().appendingPathComponent("sync/upload/\(token)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        return try await performWithAuth(urlRequest)
    }

    // MARK: - Download

    func download(token: String) async throws -> Data {
        let url = try await baseURL().appendingPathComponent("sync/download/\(token)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        return try await downloadWithAuth(urlRequest)
    }

    // MARK: - Status

    func status() async throws -> SyncStatusResponse {
        let url = try await baseURL().appendingPathComponent("sync/status")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        return try await performWithAuth(urlRequest)
    }

    // MARK: - Base URL

    private func baseURL() async throws -> URL {
        let serverURL = await deviceConfigStore.config.serverURL
        guard !serverURL.isEmpty, let url = URL(string: serverURL) else {
            throw SyncClientError.noServerURL
        }
        return url
    }

    // MARK: - Auth + Retry

    /// Execute a request with Bearer token. On 401, re-authenticates and retries once.
    private func performWithAuth<T: Decodable>(_ request: URLRequest) async throws -> T {
        var req = request
        let token = try await authManager.ensureValidToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            return try await execute(req)
        } catch SyncClientError.unauthorized {
            // Token rejected — re-authenticate with Guardian and retry once
            let newToken = try await authManager.reauthenticate()
            var retryReq = request
            retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await execute(retryReq)
        }
    }

    /// Execute a raw data download with Bearer token. On 401, retries once.
    private func downloadWithAuth(_ request: URLRequest) async throws -> Data {
        var req = request
        let token = try await authManager.ensureValidToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            return try await executeRaw(req)
        } catch SyncClientError.unauthorized {
            let newToken = try await authManager.reauthenticate()
            var retryReq = request
            retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await executeRaw(retryReq)
        }
    }

    // MARK: - HTTP Execution

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await sendRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncClientError.serverError(statusCode: 0, body: nil)
        }
        try handleStatusCode(http, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SyncClientError.decodingError(error)
        }
    }

    private func executeRaw(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await sendRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncClientError.serverError(statusCode: 0, body: nil)
        }
        try handleStatusCode(http, data: data)
        return data
    }

    private func sendRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw SyncClientError.networkError(error)
        }
    }

    private func handleStatusCode(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw SyncClientError.unauthorized
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init)
            throw SyncClientError.rateLimited(retryAfter: retryAfter)
        default:
            let body = String(data: data, encoding: .utf8)
            throw SyncClientError.serverError(statusCode: response.statusCode, body: body)
        }
    }
}
