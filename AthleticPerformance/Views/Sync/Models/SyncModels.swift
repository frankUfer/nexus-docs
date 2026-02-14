import Foundation

// MARK: - Enums

enum SyncDataCategory: String, Codable {
    case masterData = "master_data"
    case transactionalData = "transactional_data"
    case parameter
}

enum SyncEntityType: String, Codable {
    case patient
    case session
    case assessment
    case invoice
    case availability
    case documentMeta = "document_meta"
    case treatmentType = "treatment_type"
    case icdCode = "icd_code"
    case systemConfig = "system_config"
    case referenceData = "reference_data"
}

// MARK: - Push Request

struct SyncPushRequest: Codable {
    let deviceId: UUID
    let syncId: UUID
    let clientTimestamp: Date
    let lastPullVersion: Int
    let changes: [SyncPushChange]
    let attachments: [SyncAttachmentRef]

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case syncId = "sync_id"
        case clientTimestamp = "client_timestamp"
        case lastPullVersion = "last_pull_version"
        case changes, attachments
    }
}

struct SyncPushChange: Codable {
    let dataCategory: SyncDataCategory
    let entityType: SyncEntityType
    let entityId: UUID
    let patientId: UUID?
    let operation: String
    let version: Int
    let data: [String: AnyCodable]
    let clientModifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case dataCategory = "data_category"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case patientId = "patient_id"
        case operation, version, data
        case clientModifiedAt = "client_modified_at"
    }
}

struct SyncAttachmentRef: Codable {
    let entityId: UUID
    let filename: String
    let contentType: String
    let sizeBytes: Int
    let checksum: String

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case filename
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case checksum
    }
}

// MARK: - Push Response

struct SyncPushResponse: Codable {
    let syncId: UUID
    let serverTimestamp: Date
    let accepted: [SyncAcceptedChange]
    let conflicts: [SyncConflictInfo]
    let rejectedDeletions: [SyncRejectedDeletion]
    let errors: [SyncErrorInfo]
    let pendingUploads: [SyncPendingUpload]

    enum CodingKeys: String, CodingKey {
        case syncId = "sync_id"
        case serverTimestamp = "server_timestamp"
        case accepted, conflicts
        case rejectedDeletions = "rejected_deletions"
        case errors
        case pendingUploads = "pending_uploads"
    }
}

struct SyncAcceptedChange: Codable {
    let entityType: SyncEntityType
    let entityId: UUID
    let serverVersion: Int

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case entityId = "entity_id"
        case serverVersion = "server_version"
    }
}

struct SyncConflictInfo: Codable {
    let entityType: SyncEntityType
    let entityId: UUID
    let dataCategory: SyncDataCategory
    let conflictType: String
    let serverVersion: Int
    let serverData: [String: AnyCodable]
    let clientData: [String: AnyCodable]
    let resolution: String

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case entityId = "entity_id"
        case dataCategory = "data_category"
        case conflictType = "conflict_type"
        case serverVersion = "server_version"
        case serverData = "server_data"
        case clientData = "client_data"
        case resolution
    }
}

struct SyncRejectedDeletion: Codable {
    let entityType: SyncEntityType
    let entityId: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case entityId = "entity_id"
        case reason
    }
}

struct SyncErrorInfo: Codable {
    let entityType: SyncEntityType
    let entityId: UUID
    let error: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case entityId = "entity_id"
        case error, message
    }
}

struct SyncPendingUpload: Codable {
    let entityId: UUID
    let filename: String
    let uploadUrl: String

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case filename
        case uploadUrl = "upload_url"
    }
}

// MARK: - Pull Response

struct SyncPullResponse: Codable {
    let serverTimestamp: Date
    let currentVersion: Int
    let changes: [SyncPullChange]
    let hasMore: Bool
    let nextVersion: Int?

    enum CodingKeys: String, CodingKey {
        case serverTimestamp = "server_timestamp"
        case currentVersion = "current_version"
        case changes
        case hasMore = "has_more"
        case nextVersion = "next_version"
    }
}

struct SyncPullChange: Codable {
    let dataCategory: SyncDataCategory
    let entityType: SyncEntityType
    let entityId: UUID
    let patientId: UUID?
    let operation: String
    let version: Int
    let data: [String: AnyCodable]
    let serverModifiedAt: Date
    let attachments: [SyncPullAttachmentRef]?

    enum CodingKeys: String, CodingKey {
        case dataCategory = "data_category"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case patientId = "patient_id"
        case operation, version, data
        case serverModifiedAt = "server_modified_at"
        case attachments
    }
}

struct SyncPullAttachmentRef: Codable {
    let filename: String
    let downloadUrl: String

    enum CodingKeys: String, CodingKey {
        case filename
        case downloadUrl = "download_url"
    }
}

// MARK: - Upload Response

struct SyncUploadResponse: Codable {
    let entityId: UUID
    let filename: String
    let stored: Bool
    let checksumVerified: Bool

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case filename, stored
        case checksumVerified = "checksum_verified"
    }
}

// MARK: - Status Response

struct SyncStatusResponse: Codable {
    let serverTimestamp: Date
    let currentVersion: Int
    let deviceLastPush: Date?
    let deviceLastPullVersion: Int?

    enum CodingKeys: String, CodingKey {
        case serverTimestamp = "server_timestamp"
        case currentVersion = "current_version"
        case deviceLastPush = "device_last_push"
        case deviceLastPullVersion = "device_last_pull_version"
    }
}

// MARK: - AnyCodable (type-erased JSON value for data dictionaries)

struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull): return true
        case let (l as Bool, r as Bool): return l == r
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as String, r as String): return l == r
        default: return false
        }
    }
}

// MARK: - ISO8601 Date Coding Strategy with Fractional Seconds

extension JSONDecoder {
    static var syncDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.syncFormatter.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter.syncFormatterNoFraction.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }
}

extension JSONEncoder {
    static var syncEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.syncFormatter.string(from: date))
        }
        return encoder
    }
}

extension ISO8601DateFormatter {
    static let syncFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let syncFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
