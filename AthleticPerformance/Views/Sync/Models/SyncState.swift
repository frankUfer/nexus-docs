import Foundation

struct SyncState: Codable {
    var lastPullVersion: Int = 0
    var lastPushAt: Date?
    var lastSyncAt: Date?
    var pendingChangeCount: Int = 0
}

struct ConflictLogEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let entityType: SyncEntityType
    let entityId: UUID
    let resolution: String
    let serverData: [String: AnyCodable]?
    let clientData: [String: AnyCodable]?

    init(date: Date, entityType: SyncEntityType, entityId: UUID, resolution: String,
         serverData: [String: AnyCodable]? = nil, clientData: [String: AnyCodable]? = nil) {
        self.id = UUID()
        self.date = date
        self.entityType = entityType
        self.entityId = entityId
        self.resolution = resolution
        self.serverData = serverData
        self.clientData = clientData
    }
}

@MainActor
final class SyncStateStore: ObservableObject {
    @Published var state: SyncState
    @Published var conflictLog: [ConflictLogEntry] = []

    private let stateFileURL: URL
    private let conflictLogFileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let syncDir = docs.appendingPathComponent("sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: true)

        stateFileURL = syncDir.appendingPathComponent("last_sync_state.json")
        conflictLogFileURL = syncDir.appendingPathComponent("conflict_log.json")

        // Load state
        if FileManager.default.fileExists(atPath: stateFileURL.path),
           let data = try? Data(contentsOf: stateFileURL),
           let loaded = try? JSONDecoder().decode(SyncState.self, from: data) {
            state = loaded
        } else {
            state = SyncState()
        }

        // Load conflict log
        if FileManager.default.fileExists(atPath: conflictLogFileURL.path),
           let data = try? Data(contentsOf: conflictLogFileURL),
           let loaded = try? JSONDecoder().decode([ConflictLogEntry].self, from: data) {
            conflictLog = loaded
        }
    }

    func saveState() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateFileURL, options: .atomic)
    }

    func addConflict(_ entry: ConflictLogEntry) {
        conflictLog.append(entry)
        // Keep last 100 entries
        if conflictLog.count > 100 {
            conflictLog = Array(conflictLog.suffix(100))
        }
        guard let data = try? JSONEncoder().encode(conflictLog) else { return }
        try? data.write(to: conflictLogFileURL, options: .atomic)
    }
}
