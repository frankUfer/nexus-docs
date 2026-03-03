import CryptoKit
import SwiftUI

/// Setup flow for new iPads: enter 6-digit code, connect via USB, get configured automatically.
///
/// Replaces manual server URL / device ID / password entry.
/// See ADR-005: Wired iPad Onboarding and Dual-Transport Sync.
struct OnboardingView: View {
    @EnvironmentObject var deviceConfigStore: DeviceConfigStore

    @StateObject private var transportManager: TransportManager
    @State private var code = ""
    @State private var isClaimInProgress = false
    @State private var errorMessage: String?
    @State private var isComplete = false
    @State private var showWireGuardExport = false
    @State private var wireGuardConfigURL: URL?

    private let onboardingClient = OnboardingClient()

    init(deviceConfigStore: DeviceConfigStore) {
        _transportManager = StateObject(wrappedValue: TransportManager(deviceConfigStore: deviceConfigStore))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                headerSection
                connectionStatusSection
                codeEntrySection
                if let error = errorMessage {
                    errorSection(error)
                }

                // Debug info — remove after onboarding is verified
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug:").font(.caption.bold())
                    Text("Transport: \(transportManager.currentTransport.rawValue)")
                    Text("Reachable: \(transportManager.isServerReachable ? "yes" : "no")")
                    Text("Server: \(transportManager.discoveredServer?.baseURL ?? "none")")
                    Text("Bonjour: \(transportManager.bonjourDebugStatus)")
                    Text("Health: \(transportManager.healthDebug)")
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                Spacer()
            }
            .padding()
            .navigationTitle("Setup")
            .onAppear {
                transportManager.startMonitoring()
            }
            .onDisappear {
                transportManager.stopMonitoring()
            }
            .sheet(isPresented: $showWireGuardExport, onDismiss: {
                // Delete temp file — private key must not persist on disk
                if let url = wireGuardConfigURL {
                    try? FileManager.default.removeItem(at: url)
                    wireGuardConfigURL = nil
                }
            }) {
                if let url = wireGuardConfigURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cable.connector")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Connect to Nexus")
                .font(.title2.bold())

            Text("Connect this iPad to the server via network cable, then enter the 6-digit setup code from your admin.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Connection Status

    private var connectionStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: connectionIcon)
                .foregroundStyle(connectionColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(connectionTitle)
                    .font(.headline)
                Text(connectionDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if transportManager.isServerReachable {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var connectionIcon: String {
        switch transportManager.currentTransport {
        case .wired: return "cable.connector"
        case .vpn: return "network"
        case .none: return "wifi.slash"
        }
    }

    private var connectionColor: Color {
        transportManager.isServerReachable ? .green : .orange
    }

    private var connectionTitle: String {
        if transportManager.isServerReachable {
            return "Server found"
        }
        switch transportManager.currentTransport {
        case .wired: return "USB connected — searching..."
        case .vpn: return "Network connected — searching..."
        case .none: return "No connection"
        }
    }

    private var connectionDetail: String {
        if let server = transportManager.discoveredServer {
            return "\(server.host):\(server.port) (\(server.tier))"
        }
        return "Connect via network cable to continue"
    }

    // MARK: - Code Entry

    private var codeEntrySection: some View {
        VStack(spacing: 16) {
            TextField("000000", text: $code)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .frame(maxWidth: 200)
                .textFieldStyle(.roundedBorder)
                .onChange(of: code) { _, newValue in
                    // Limit to 6 digits
                    code = String(newValue.filter(\.isNumber).prefix(6))
                }

            Button {
                Task { await claimCode() }
            } label: {
                if isClaimInProgress {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Activate")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(code.count != 6 || !transportManager.isServerReachable || isClaimInProgress)
        }
    }

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
        .padding()
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Claim Flow

    private func claimCode() async {
        guard let serverURL = transportManager.preferredServerURL else {
            errorMessage = "No server URL available"
            return
        }

        isClaimInProgress = true
        errorMessage = nil

        do {
            // Generate WireGuard Curve25519 keypair for full-tier deployments
            var wgPublicKey: String? = KeychainHelper.loadWireGuardPublicKey()
            if wgPublicKey == nil, transportManager.discoveredServer?.tier == "full" {
                let privateKey = Curve25519.KeyAgreement.PrivateKey()
                let privBase64 = privateKey.rawRepresentation.base64EncodedString()
                let pubBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
                _ = KeychainHelper.saveWireGuardPrivateKey(privBase64)
                _ = KeychainHelper.saveWireGuardPublicKey(pubBase64)
                wgPublicKey = pubBase64
            }

            let response = try await onboardingClient.claim(
                code: code,
                wgPublicKey: wgPublicKey,
                serverBaseURL: serverURL
            )

            // Apply configuration
            applyClaimResponse(response)
            isComplete = true

        } catch {
            errorMessage = error.localizedDescription
        }

        isClaimInProgress = false
    }

    private func applyClaimResponse(_ response: ClaimResponse) {
        guard let deviceId = UUID(uuidString: response.deviceId) else { return }

        deviceConfigStore.config = DeviceConfig(
            deviceId: deviceId,
            deviceName: response.deviceName,
            serverURL: response.serverUrl,
            guardianURL: response.guardianUrl ?? "",
            isRegistered: true,
            deploymentTier: response.deploymentTier,
            wireguardConfig: response.wireguardConfig
        )
        deviceConfigStore.save()

        // Store password in Keychain if provided (full tier)
        if let password = response.password {
            _ = KeychainHelper.saveDevicePassword(password)
        }

        // Store WireGuard config and export for WireGuard app
        if let wgConfig = response.wireguardConfig {
            _ = KeychainHelper.save(wgConfig, account: "wg_config")

            // Inject PrivateKey and present share sheet for WireGuard app import
            if let privKey = KeychainHelper.loadWireGuardPrivateKey() {
                let fullConfig = wgConfig.replacingOccurrences(
                    of: "[Interface]",
                    with: "[Interface]\nPrivateKey = \(privKey)"
                )
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("nexus-vpn.conf")
                try? fullConfig.write(to: tempURL, atomically: true, encoding: .utf8)
                wireGuardConfigURL = tempURL
                showWireGuardExport = true
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
