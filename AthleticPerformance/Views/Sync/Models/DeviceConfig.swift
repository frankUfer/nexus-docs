import Foundation

struct DeviceConfig: Codable {
    var deviceId: UUID
    var deviceName: String
    var serverURL: String
    var guardianURL: String
    var isRegistered: Bool
    var deploymentTier: String  // "full" or "local"
    var wireguardConfig: String?  // WireGuard client config (full tier only)

    /// Whether this device was provisioned (has a server URL and is registered).
    var isProvisioned: Bool {
        isRegistered && !serverURL.isEmpty
    }

    /// Whether this is a full-tier deployment (VPN + Guardian).
    var isFullTier: Bool {
        deploymentTier == "full"
    }

    static func `default`() -> DeviceConfig {
        DeviceConfig(
            deviceId: UUID(),
            deviceName: "",
            serverURL: "",
            guardianURL: "",
            isRegistered: false,
            deploymentTier: "local",
            wireguardConfig: nil
        )
    }

    // Backward-compatible decoding: existing files without new fields still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(UUID.self, forKey: .deviceId)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        serverURL = try container.decode(String.self, forKey: .serverURL)
        guardianURL = try container.decodeIfPresent(String.self, forKey: .guardianURL) ?? ""
        isRegistered = try container.decode(Bool.self, forKey: .isRegistered)
        deploymentTier = try container.decodeIfPresent(String.self, forKey: .deploymentTier) ?? "local"
        wireguardConfig = try container.decodeIfPresent(String.self, forKey: .wireguardConfig)
    }

    init(deviceId: UUID, deviceName: String, serverURL: String, guardianURL: String,
         isRegistered: Bool, deploymentTier: String = "local", wireguardConfig: String? = nil) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.serverURL = serverURL
        self.guardianURL = guardianURL
        self.isRegistered = isRegistered
        self.deploymentTier = deploymentTier
        self.wireguardConfig = wireguardConfig
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
