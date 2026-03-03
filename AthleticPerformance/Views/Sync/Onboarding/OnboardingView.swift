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

            Text("Connect this iPad to the server via USB cable, then enter the 6-digit setup code from your admin.")
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
        return "Connect via USB cable to continue"
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
            // For full tier, we'd generate WireGuard keys here
            let wgPublicKey = KeychainHelper.loadWireGuardPublicKey()

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

        // Store WireGuard config if provided
        if let wgConfig = response.wireguardConfig {
            _ = KeychainHelper.save(wgConfig, account: "wg_config")
        }
    }
}
