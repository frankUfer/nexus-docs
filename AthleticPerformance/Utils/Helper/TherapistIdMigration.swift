import Foundation

/// Deterministic mapping from legacy Int therapist IDs to UUIDs.
/// Maps e.g. `1` → `"00000000-0000-0000-0000-000000000001"`.
func therapistUUIDFromInt(_ intId: Int) -> UUID {
    let hex = String(format: "%012x", intId)
    let uuidString = "00000000-0000-0000-0000-\(hex)"
    return UUID(uuidString: uuidString)!
}

/// Decodes a required therapistId that may be stored as Int (legacy) or UUID (current).
func decodeTherapistId<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) throws -> UUID {
    if let uuid = try? container.decode(UUID.self, forKey: key) {
        return uuid
    }
    let intId = try container.decode(Int.self, forKey: key)
    return therapistUUIDFromInt(intId)
}

/// Decodes an optional therapistId that may be stored as Int (legacy) or UUID (current).
func decodeOptionalTherapistId<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) throws -> UUID? {
    if let uuid = try? container.decodeIfPresent(UUID.self, forKey: key) {
        return uuid
    }
    if let intId = try? container.decodeIfPresent(Int.self, forKey: key) {
        return therapistUUIDFromInt(intId)
    }
    return nil
}
