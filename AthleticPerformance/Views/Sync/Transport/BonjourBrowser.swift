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
    @Published private(set) var debugStatus: String = "not started"

    private var browser: NWBrowser?
    private var resolveConnection: NWConnection?

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
                    self?.debugStatus = "ready"
                case .cancelled:
                    self?.isSearching = false
                    self?.debugStatus = "cancelled"
                case .failed(let error):
                    self?.isSearching = false
                    self?.debugStatus = "failed: \(error)"
                case .waiting(let error):
                    self?.debugStatus = "waiting: \(error)"
                default:
                    self?.debugStatus = "state: \(state)"
                }
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.debugStatus = "found \(results.count) service(s)"
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
        resolveConnection?.cancel()
        resolveConnection = nil
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
            tier = parseTier(from: txtRecord)
        } else {
            tier = "full"
        }

        // Cancel any previous resolve attempt
        resolveConnection?.cancel()
        resolveConnection = nil

        // Extract host and port from the endpoint
        if case let .service(name, type, domain, _) = result.endpoint {
            debugStatus = "resolving \(name)..."
            // Use NWConnection to resolve the service name to a host:port
            // Force IPv4 to avoid link-local IPv6 issues in URLs
            let params = NWParameters.tcp
            if let ipOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                ipOptions.version = .v4
            }
            let connection = NWConnection(to: result.endpoint, using: params)
            resolveConnection = connection  // retain the connection

            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case let .hostPort(host, port) = innerEndpoint {
                        var hostString: String
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
                        // Strip interface scope ID (e.g. "%en5") — invalid in URLs
                        if let pct = hostString.firstIndex(of: "%") {
                            hostString = String(hostString[..<pct])
                        }
                        Task { @MainActor in
                            self?.debugStatus = "resolved: \(hostString):\(port.rawValue)"
                            self?.discoveredEndpoint = ResolvedEndpoint(
                                host: hostString,
                                port: Int(port.rawValue),
                                tier: tier
                            )
                        }
                    }
                    connection.cancel()

                case .failed(let error):
                    Task { @MainActor in
                        self?.debugStatus = "resolve failed: \(error)"
                    }
                    connection.cancel()

                case .waiting(let error):
                    Task { @MainActor in
                        self?.debugStatus = "resolve waiting: \(error)"
                    }

                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}

// MARK: - NWTXTRecord Helpers

/// Extract the deployment tier from a Bonjour TXT record.
/// Falls back to "full" if parsing fails.
private func parseTier(from txtRecord: NWTXTRecord) -> String {
    // NWTXTRecord stores DNS TXT data as length-prefixed key=value entries
    let description = String(describing: txtRecord)
    // The description format includes key=value pairs
    if description.contains("tier=local") {
        return "local"
    }
    return "full"
}
