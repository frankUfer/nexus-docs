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
    @State private var manualServerURL = "https://192.168.178.2:8443"
    @State private var isClaimInProgress = false
    @State private var errorMessage: String?
    @State private var isComplete = false
    @State private var showWireGuardExport = false
    @State private var wireGuardConfigURL: URL?
    /// Deferred claim response — saved after WireGuard share sheet is dismissed
    /// so the view isn't killed before the sheet can present.
    @State private var pendingClaimResponse: ClaimResponse?

    private let onboardingClient = OnboardingClient()

    init(deviceConfigStore: DeviceConfigStore) {
        _transportManager = StateObject(wrappedValue: TransportManager(deviceConfigStore: deviceConfigStore))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                headerSection
                connectionStatusSection
                manualServerSection
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
                // NOW save config — triggers isProvisioned → navigation away
                if let response = pendingClaimResponse {
                    finalizeProvisioning(response)
                    pendingClaimResponse = nil
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

    // MARK: - Manual Server

    private var manualServerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server URL (if Bonjour fails)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("https://server-ip:8443", text: $manualServerURL)
                    .font(.body.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)

                Button("Connect") {
                    applyManualServer()
                }
                .buttonStyle(.bordered)
                .disabled(manualServerURL.isEmpty)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func applyManualServer() {
        var url = manualServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http") {
            url = "https://\(url)"
        }
        guard URL(string: url) != nil else {
            errorMessage = "Invalid URL"
            return
        }
        // Set serverURL on config so TransportManager.manualServer() finds it
        deviceConfigStore.config.serverURL = url
        // Trigger reachability check against the manual URL
        Task { await transportManager.checkReachability() }
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
            .disabled(code.count != 6 || !canActivate || isClaimInProgress)
        }
    }

    private var canActivate: Bool {
        transportManager.isServerReachable
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
        // Store password in Keychain if provided (full tier)
        if let password = response.password {
            _ = KeychainHelper.saveDevicePassword(password)
        }

        // Store WireGuard config and present share sheet BEFORE saving device config.
        // Saving config sets isProvisioned=true which navigates away from this view,
        // so we must show the share sheet first and defer the save to onDismiss.
        if let wgConfig = response.wireguardConfig {
            _ = KeychainHelper.save(wgConfig, account: "wg_config")

            if let privKey = KeychainHelper.loadWireGuardPrivateKey() {
                let fullConfig = wgConfig.replacingOccurrences(
                    of: "[Interface]",
                    with: "[Interface]\nPrivateKey = \(privKey)"
                )
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("nexus-vpn.conf")
                try? fullConfig.write(to: tempURL, atomically: true, encoding: .utf8)
                wireGuardConfigURL = tempURL
                pendingClaimResponse = response
                showWireGuardExport = true
                return
            }
        }

        // No WireGuard config (lite tier) — save immediately
        finalizeProvisioning(response)
    }

    private func finalizeProvisioning(_ response: ClaimResponse) {
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
