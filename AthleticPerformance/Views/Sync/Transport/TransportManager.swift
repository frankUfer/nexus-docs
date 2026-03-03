import Foundation
import Combine
import Network

/// Detected transport type for connecting to the Nexus server.
enum TransportType: String {
    case wired   // USB cable — use X-Device-ID auth
    case vpn     // WireGuard VPN — use JWT Bearer auth
    case none    // No connection detected
}

/// Discovered Nexus server via Bonjour or manual configuration.
struct DiscoveredServer: Equatable {
    let host: String
    let port: Int
    let tier: String  // "full" or "local"
    let transport: TransportType

    var baseURL: String {
        "https://\(host):\(port)"
    }
}

/// Manages transport detection and server discovery for dual-transport sync (ADR-005).
///
/// Uses NWPathMonitor to detect wired (USB) vs VPN connections and NWBrowser
/// to discover Nexus servers via Bonjour (`_nexus._tcp`). Publishes the current
/// transport type and preferred server for the sync client.
@MainActor
final class TransportManager: ObservableObject {
    @Published private(set) var currentTransport: TransportType = .none
    @Published private(set) var discoveredServer: DiscoveredServer?
    @Published private(set) var isServerReachable = false

    private let bonjourBrowser = BonjourBrowser()
    private let deviceConfigStore: DeviceConfigStore
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "nexus.transport.monitor")
    private var cancellables = Set<AnyCancellable>()
    private var pollTimer: AnyCancellable?

    init(deviceConfigStore: DeviceConfigStore) {
        self.deviceConfigStore = deviceConfigStore
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        // Monitor network path changes
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        pathMonitor.start(queue: monitorQueue)

        // Start Bonjour discovery
        bonjourBrowser.start()

        // Observe Bonjour results
        bonjourBrowser.$discoveredEndpoint
            .receive(on: RunLoop.main)
            .sink { [weak self] endpoint in
                self?.handleBonjourResult(endpoint)
            }
            .store(in: &cancellables)

        // Periodic reachability check
        pollTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.checkReachability() }
            }

        // Initial check
        Task { await checkReachability() }
    }

    func stopMonitoring() {
        pathMonitor.cancel()
        bonjourBrowser.stop()
        cancellables.removeAll()
        pollTimer?.cancel()
        pollTimer = nil
    }

    // MARK: - Path Monitoring

    private func handlePathUpdate(_ path: NWPath) {
        let hasWired = path.availableInterfaces.contains { iface in
            // USB Ethernet shows as .wiredEthernet or sometimes .other
            iface.type == .wiredEthernet || iface.type == .other
        }
        let hasWiFi = path.availableInterfaces.contains { $0.type == .wifi }

        if hasWired {
            currentTransport = .wired
        } else if hasWiFi || path.status == .satisfied {
            // VPN runs over WiFi or cellular
            currentTransport = .vpn
        } else {
            currentTransport = .none
        }
    }

    // MARK: - Bonjour Results

    private func handleBonjourResult(_ endpoint: BonjourBrowser.ResolvedEndpoint?) {
        guard let endpoint else {
            // Bonjour lost the server — fall back to manual config
            updateFromManualConfig()
            return
        }

        discoveredServer = DiscoveredServer(
            host: endpoint.host,
            port: endpoint.port,
            tier: endpoint.tier,
            transport: currentTransport
        )

        Task { await checkReachability() }
    }

    // MARK: - Reachability

    func checkReachability() async {
        guard let server = discoveredServer ?? manualServer() else {
            isServerReachable = false
            return
        }

        guard let url = URL(string: "\(server.baseURL)/health") else {
            isServerReachable = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            isServerReachable = http?.statusCode == 200
        } catch {
            isServerReachable = false
        }
    }

    // MARK: - Server Resolution

    /// The preferred server URL, using Bonjour discovery or manual config.
    var preferredServerURL: String? {
        discoveredServer?.baseURL ?? manualServerURL()
    }

    /// Whether the current connection uses wired (X-Device-ID) auth.
    var isWired: Bool {
        currentTransport == .wired
    }

    // MARK: - Private

    private func manualServer() -> DiscoveredServer? {
        let config = deviceConfigStore.config
        guard !config.serverURL.isEmpty,
              let url = URL(string: config.serverURL) else { return nil }
        return DiscoveredServer(
            host: url.host ?? "localhost",
            port: url.port ?? 8443,
            tier: config.guardianURL.isEmpty ? "local" : "full",
            transport: currentTransport
        )
    }

    private func manualServerURL() -> String? {
        let url = deviceConfigStore.config.serverURL
        return url.isEmpty ? nil : url
    }

    private func updateFromManualConfig() {
        discoveredServer = manualServer()
    }
}
