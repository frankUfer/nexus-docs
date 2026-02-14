import Foundation

struct QueuedChange: Codable, Identifiable {
    let id: UUID
    let entityType: SyncEntityType
    let entityId: UUID
    let patientId: UUID?
    let dataCategory: SyncDataCategory
    let data: [String: AnyCodable]
    let operation: String
    let queuedAt: Date

    init(entityType: SyncEntityType, entityId: UUID, patientId: UUID?,
         dataCategory: SyncDataCategory, data: [String: AnyCodable], operation: String) {
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.patientId = patientId
        self.dataCategory = dataCategory
        self.data = data
        self.operation = operation
        self.queuedAt = Date()
    }
}

@MainActor
final class OutboundQueue: ObservableObject {
    @Published private(set) var items: [QueuedChange] = []

    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let syncDir = docs.appendingPathComponent("sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: true)
        fileURL = syncDir.appendingPathComponent("outbound_queue.json")
        load()
    }

    func enqueue(_ change: QueuedChange) {
        // Replace existing entry for same entity (latest change wins)
        items.removeAll { $0.entityId == change.entityId }
        items.append(change)
        save()
    }

    func enqueueAll(_ changes: [QueuedChange]) {
        for change in changes {
            items.removeAll { $0.entityId == change.entityId }
            items.append(change)
        }
        save()
    }

    func dequeueAll() -> [QueuedChange] {
        let all = items
        items.removeAll()
        save()
        return all
    }

    func markSynced(entityIds: Set<UUID>) {
        items.removeAll { entityIds.contains($0.entityId) }
        save()
    }

    func requeue(_ changes: [QueuedChange]) {
        for change in changes {
            if !items.contains(where: { $0.entityId == change.entityId }) {
                items.append(change)
            }
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([QueuedChange].self, from: data)
        else { return }
        items = loaded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
