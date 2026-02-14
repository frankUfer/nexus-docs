import Foundation
import Combine

/// Polls the sync server's status endpoint to track connectivity.
/// Publishes `isServerReachable` for the UI and auto-sync logic.
@MainActor
final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isServerReachable = false

    private let client: NexusSyncClient
    private var pollTimer: AnyCancellable?
    private let pollInterval: TimeInterval

    init(client: NexusSyncClient, pollInterval: TimeInterval = 30) {
        self.client = client
        self.pollInterval = pollInterval
    }

    func startMonitoring() {
        // Check immediately
        Task { await checkConnectivity() }

        // Then poll periodically
        pollTimer = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.checkConnectivity() }
            }
    }

    func stopMonitoring() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    func checkConnectivity() async {
        do {
            _ = try await client.status()
            isServerReachable = true
        } catch {
            isServerReachable = false
        }
    }
}
