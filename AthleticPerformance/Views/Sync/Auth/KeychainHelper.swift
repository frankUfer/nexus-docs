import Foundation
import Security

/// Metadata stored alongside the JWT token to track expiry.
struct TokenMetadata: Codable {
    let obtainedAt: Date
    let expiresIn: TimeInterval

    var expiresAt: Date { obtainedAt.addingTimeInterval(expiresIn) }
    var refreshAt: Date { obtainedAt.addingTimeInterval(expiresIn * 0.8) }
    var isExpired: Bool { Date() >= expiresAt }
    var needsRefresh: Bool { Date() >= refreshAt }
}

enum KeychainHelper {
    private static let service = "com.athletic-performance.nexus-sync"

    // MARK: - Generic Operations

    static func save(_ value: String, account: String) -> Bool {
        delete(account: account)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - JWT Token

    static func saveToken(_ token: String) -> Bool {
        save(token, account: "jwt")
    }

    static func loadToken() -> String? {
        load(account: "jwt")
    }

    @discardableResult
    static func deleteToken() -> Bool {
        delete(account: "jwt")
    }

    // MARK: - Device Password

    static func saveDevicePassword(_ password: String) -> Bool {
        save(password, account: "device_password")
    }

    static func loadDevicePassword() -> String? {
        load(account: "device_password")
    }

    @discardableResult
    static func deleteDevicePassword() -> Bool {
        delete(account: "device_password")
    }

    // MARK: - Token Metadata

    static func saveTokenMetadata(_ metadata: TokenMetadata) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(metadata),
              let string = String(data: data, encoding: .utf8) else { return false }
        return save(string, account: "jwt_metadata")
    }

    static func loadTokenMetadata() -> TokenMetadata? {
        guard let string = load(account: "jwt_metadata"),
              let data = string.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(TokenMetadata.self, from: data)
    }

    @discardableResult
    static func deleteTokenMetadata() -> Bool {
        delete(account: "jwt_metadata")
    }
}
