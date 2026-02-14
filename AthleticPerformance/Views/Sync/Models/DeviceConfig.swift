import Foundation

struct DeviceConfig: Codable {
    var deviceId: UUID
    var deviceName: String
    var serverURL: String
    var isRegistered: Bool

    static func `default`() -> DeviceConfig {
        DeviceConfig(
            deviceId: UUID(),
            deviceName: "",
            serverURL: "",
            isRegistered: false
        )
    }
}

@MainActor
final class DeviceConfigStore: ObservableObject {
    @Published var config: DeviceConfig

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let syncDir = docs.appendingPathComponent("sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: true)
        fileURL = syncDir.appendingPathComponent("device_config.json")

        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(DeviceConfig.self, from: data) {
            config = loaded
        } else {
            config = .default()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
