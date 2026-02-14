import Foundation

/// Tracks synced entity versions to determine create vs update operations
/// and provide correct version numbers for push requests.
@MainActor
final class EntityVersionTracker: ObservableObject {

    struct TrackedEntity: Codable {
        let entityType: SyncEntityType
        var serverVersion: Int
        var lastSyncedAt: Date
    }

    @Published private(set) var entities: [UUID: TrackedEntity] = [:]

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let syncDir = docs.appendingPathComponent("sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: true)
        fileURL = syncDir.appendingPathComponent("entity_versions.json")
        load()
    }

    /// Returns "create" if entity has never been synced, "update" otherwise.
    func operation(for entityId: UUID) -> String {
        entities[entityId] != nil ? "update" : "create"
    }

    /// Returns the last known server version for an entity (0 if never synced).
    func version(for entityId: UUID) -> Int {
        entities[entityId]?.serverVersion ?? 0
    }

    /// Updates the tracked version after a successful push acceptance.
    func updateVersion(entityId: UUID, entityType: SyncEntityType, serverVersion: Int) {
        entities[entityId] = TrackedEntity(
            entityType: entityType,
            serverVersion: serverVersion,
            lastSyncedAt: Date()
        )
        save()
    }

    /// Updates versions from a pull response (server-side changes).
    func updateFromPull(entityId: UUID, entityType: SyncEntityType, version: Int) {
        entities[entityId] = TrackedEntity(
            entityType: entityType,
            serverVersion: version,
            lastSyncedAt: Date()
        )
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([UUID: TrackedEntity].self, from: data)
        else { return }
        entities = loaded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entities) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
