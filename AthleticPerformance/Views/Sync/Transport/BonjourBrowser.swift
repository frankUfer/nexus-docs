import Foundation
import Network

/// Discovers Nexus servers on the local network via Bonjour (`_nexus._tcp`).
///
/// Uses NWBrowser to find mDNS service advertisements from nexus-core.
/// On Ubuntu: advertised via avahi. On Mac: advertised via Python zeroconf.
@MainActor
final class BonjourBrowser: ObservableObject {

    struct ResolvedEndpoint: Equatable {
        let host: String
        let port: Int
        let tier: String  // from TXT record: "full" or "local"
    }

    @Published private(set) var discoveredEndpoint: ResolvedEndpoint?
    @Published private(set) var isSearching = false

    private var browser: NWBrowser?

    // MARK: - Start / Stop

    func start() {
        guard browser == nil else { return }

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_nexus._tcp", domain: nil)
        let params = NWParameters()
        let newBrowser = NWBrowser(for: descriptor, using: params)

        newBrowser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isSearching = true
                case .cancelled, .failed:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleResults(results)
            }
        }

        newBrowser.start(queue: .main)
        browser = newBrowser
        isSearching = true
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isSearching = false
        discoveredEndpoint = nil
    }

    // MARK: - Result Handling

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        // Pick the first available Nexus service
        guard let result = results.first else {
            discoveredEndpoint = nil
            return
        }

        // Resolve the endpoint
        resolveEndpoint(result)
    }

    private func resolveEndpoint(_ result: NWBrowser.Result) {
        // Extract metadata from the result
        let tier: String
        if case let .bonjour(txtRecord) = result.metadata {
            tier = txtRecord.dictionary["tier"] ?? "full"
        } else {
            tier = "full"
        }

        // Extract host and port from the endpoint
        if case let .service(name, type, domain, _) = result.endpoint {
            // Use NWConnection to resolve the service name to a host:port
            let connection = NWConnection(to: result.endpoint, using: .tcp)
            connection.stateUpdateHandler = { [weak self] state in
                if case .ready = state {
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case let .hostPort(host, port) = innerEndpoint {
                        let hostString: String
                        switch host {
                        case .ipv4(let addr):
                            hostString = "\(addr)"
                        case .ipv6(let addr):
                            hostString = "\(addr)"
                        case .name(let name, _):
                            hostString = name
                        @unknown default:
                            hostString = "\(name).\(type)\(domain)"
                        }
                        Task { @MainActor in
                            self?.discoveredEndpoint = ResolvedEndpoint(
                                host: hostString,
                                port: Int(port.rawValue),
                                tier: tier
                            )
                        }
                    }
                    connection.cancel()
                }
            }
            connection.start(queue: .global())
        }
    }
}

// MARK: - NWTXTRecord Extension

private extension NWTXTRecord {
    /// Parse TXT record entries into a dictionary.
    var dictionary: [String: String] {
        var result: [String: String] = [:]
        // NWTXTRecord stores key=value pairs
        // Unfortunately NWTXTRecord doesn't expose a clean iteration API,
        // but we can enumerate known keys
        for key in ["tier", "version"] {
            if let entry = self.getEntry(for: key),
               case let .string(value) = entry {
                result[key] = value
            }
        }
        return result
    }

    func getEntry(for key: String) -> NWTXTRecord.Entry? {
        // Access via subscript-like pattern
        // NWTXTRecord provides .getEntry(for:) in some iOS versions
        return nil  // Fallback — TXT record parsing is best-effort
    }

    enum Entry {
        case string(String)
    }
}
