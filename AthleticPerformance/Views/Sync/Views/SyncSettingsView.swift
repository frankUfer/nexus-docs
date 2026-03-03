import SwiftUI

/// Sync settings: shows current configuration (auto-provisioned via onboarding) and connection status.
///
/// Manual configuration is still available as a fallback for advanced users.
struct SyncSettingsView: View {
    @EnvironmentObject var deviceConfigStore: DeviceConfigStore
    @EnvironmentObject var authManager: AuthManager

    @State private var serverURL: String = ""
    @State private var guardianURL: String = ""
    @State private var deviceName: String = ""
    @State private var deviceIdInput: String = ""
    @State private var passwordInput: String = ""
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var showManualConfig = false
    @State private var showWireGuardExport = false
    @State private var wireGuardConfigURL: URL?
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            if deviceConfigStore.config.isProvisioned {
                provisionedSection
            }
            if deviceConfigStore.config.isFullTier {
                vpnSection
            }
            if showManualConfig || !deviceConfigStore.config.isProvisioned {
                serverSection
                deviceSection
                authSection
                saveSection
            }
            connectionSection
            if deviceConfigStore.config.isProvisioned && !showManualConfig {
                Section {
                    Button("Show Manual Configuration") {
                        showManualConfig = true
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            if deviceConfigStore.config.isProvisioned {
                Section {
                    Button("Reset Provisioning", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .font(.caption)
                } footer: {
                    Text("Clears device config so you can re-run onboarding via cable.")
                }
            }
        }
        .navigationTitle(NSLocalizedString("syncSettingsTitle", comment: "Sync Settings"))
        .onAppear { loadFields() }
        .sheet(isPresented: $showWireGuardExport, onDismiss: {
            if let url = wireGuardConfigURL {
                try? FileManager.default.removeItem(at: url)
                wireGuardConfigURL = nil
            }
        }) {
            if let url = wireGuardConfigURL {
                WireGuardShareSheet(items: [url])
            }
        }
        .alert("Reset Provisioning?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                deviceConfigStore.config = DeviceConfig.default()
                deviceConfigStore.save()
                authManager.clearAll()
            }
        } message: {
            Text("This will clear all device configuration. You will need to re-onboard via cable.")
        }
    }

    // MARK: - Provisioned Status

    private var provisionedSection: some View {
        Section("Device Status") {
            LabeledContent("Device", value: deviceConfigStore.config.deviceName)
            LabeledContent("Server", value: deviceConfigStore.config.serverURL)
            LabeledContent("Tier", value: deviceConfigStore.config.deploymentTier.capitalized)
            if deviceConfigStore.config.isFullTier {
                LabeledContent("Guardian", value: deviceConfigStore.config.guardianURL)
            }
            HStack {
                Text("Provisioned")
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Server Configuration

    private var serverSection: some View {
        Section(NSLocalizedString("syncServerConfig", comment: "Server Configuration")) {
            TextField(NSLocalizedString("syncServerURL", comment: "nexus-core URL"), text: $serverURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { saveServerURL() }

            TextField(NSLocalizedString("syncGuardianURL", comment: "Guardian URL"), text: $guardianURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { saveGuardianURL() }

            TextField(NSLocalizedString("syncDeviceName", comment: "Device Name"), text: $deviceName)
                .onSubmit { saveDeviceName() }
        }
    }

    // MARK: - Device Identity

    private var deviceSection: some View {
        Section(NSLocalizedString("syncDeviceInfo", comment: "Device Identity")) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("syncDeviceId", comment: "Device ID"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("UUID", text: $deviceIdInput)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { saveDeviceId() }
            }

            HStack {
                Text(NSLocalizedString("syncRegistered", comment: "Registered"))
                Spacer()
                Image(systemName: deviceConfigStore.config.isRegistered ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(deviceConfigStore.config.isRegistered ? .green : .red)
            }
        }
    }

    // MARK: - Authentication

    private var authSection: some View {
        Section(NSLocalizedString("syncAuthentication", comment: "Authentication")) {
            // Auth status
            HStack {
                Text(NSLocalizedString("syncAuthStatus", comment: "Status"))
                Spacer()
                authStatusBadge
            }

            // Token expiry
            if case .authenticated(let expiresAt) = authManager.status {
                HStack {
                    Text(NSLocalizedString("syncTokenExpires", comment: "Token Expires"))
                    Spacer()
                    Text(expiresAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Rate limit warning
            if case .rateLimited(let retryAfter) = authManager.status {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(NSLocalizedString("syncRateLimited", comment: "Rate limited — retry after"))
                    Text(retryAfter, style: .relative)
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }

            // Device password
            SecureField(NSLocalizedString("syncDevicePassword", comment: "Device Password"), text: $passwordInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Button(NSLocalizedString("syncSavePassword", comment: "Save Password")) {
                    guard !passwordInput.isEmpty else { return }
                    _ = KeychainHelper.saveDevicePassword(passwordInput)
                    passwordInput = ""
                    authManager.updateStatus()
                }
                .disabled(passwordInput.isEmpty)

                Spacer()

                Button(NSLocalizedString("syncClearCredentials", comment: "Clear Credentials"), role: .destructive) {
                    authManager.clearAll()
                }
            }

            // Authenticate button
            Button {
                Task { await authManager.authenticate() }
            } label: {
                HStack {
                    if case .authenticating = authManager.status {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Label(NSLocalizedString("syncAuthenticate", comment: "Authenticate"), systemImage: "lock.shield")
                }
            }
            .disabled(!authManager.isConfigured || authManager.status == .authenticating)
        }
    }

    // MARK: - Auth Status Badge

    @ViewBuilder
    private var authStatusBadge: some View {
        switch authManager.status {
        case .unconfigured:
            Label(NSLocalizedString("syncStatusUnconfigured", comment: "Not configured"), systemImage: "gear.badge.xmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unauthenticated:
            Label(NSLocalizedString("syncStatusUnauthenticated", comment: "Not authenticated"), systemImage: "lock.open")
                .font(.caption)
                .foregroundStyle(.orange)
        case .authenticating:
            Label(NSLocalizedString("syncStatusAuthenticating", comment: "Authenticating..."), systemImage: "lock.rotation")
                .font(.caption)
                .foregroundStyle(.blue)
        case .authenticated:
            Label(NSLocalizedString("syncStatusAuthenticated", comment: "Authenticated"), systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .rateLimited:
            Label(NSLocalizedString("syncStatusRateLimited", comment: "Rate limited"), systemImage: "hand.raised.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    // MARK: - Connection Test

    private var connectionSection: some View {
        Section(NSLocalizedString("syncTestConnection", comment: "Connection Test")) {
            Button {
                testConnection()
            } label: {
                if isTesting {
                    ProgressView()
                } else {
                    Label(NSLocalizedString("syncTestButton", comment: "Test Connection"), systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .disabled(isTesting || guardianURL.isEmpty)

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("Server OK") ? .green : .orange)
            }
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        Section {
            Button(NSLocalizedString("syncSaveSettings", comment: "Save Settings")) {
                saveAll()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func loadFields() {
        serverURL = deviceConfigStore.config.serverURL
        guardianURL = deviceConfigStore.config.guardianURL
        deviceName = deviceConfigStore.config.deviceName
        deviceIdInput = deviceConfigStore.config.deviceId.uuidString
    }

    private func saveServerURL() {
        deviceConfigStore.config.serverURL = serverURL
        deviceConfigStore.save()
    }

    private func saveGuardianURL() {
        deviceConfigStore.config.guardianURL = guardianURL
        deviceConfigStore.save()
        authManager.updateStatus()
    }

    private func saveDeviceName() {
        deviceConfigStore.config.deviceName = deviceName
        deviceConfigStore.save()
    }

    private func saveDeviceId() {
        guard let uuid = UUID(uuidString: deviceIdInput) else { return }
        deviceConfigStore.config.deviceId = uuid
        deviceConfigStore.save()
    }

    private func saveAll() {
        saveServerURL()
        saveGuardianURL()
        saveDeviceName()
        saveDeviceId()
    }

    // MARK: - VPN Config Export

    private var vpnSection: some View {
        Section("VPN (WireGuard)") {
            if deviceConfigStore.config.wireguardConfig != nil {
                Button {
                    exportWireGuardConfig()
                } label: {
                    Label("Export VPN Config", systemImage: "square.and.arrow.up")
                }

                Text("Opens share sheet — tap \"WireGuard\" to import the tunnel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No VPN config available. Re-run onboarding via cable to generate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exportWireGuardConfig() {
        guard let wgConfig = deviceConfigStore.config.wireguardConfig else {
            testResult = "No WireGuard config stored. Re-run onboarding via cable."
            return
        }
        guard let privKey = KeychainHelper.loadWireGuardPrivateKey() else {
            testResult = "No WireGuard private key in Keychain. Re-run onboarding via cable."
            return
        }

        // Validate required fields before creating config file
        if !wgConfig.contains("PublicKey") {
            testResult = "Stored config is missing server PublicKey. Re-run onboarding via cable to get a valid config."
            return
        }
        if wgConfig.contains("nexus-gate.local") {
            testResult = "Stored config has local-only endpoint. Re-run onboarding via cable after setting NEXUS_WG_ENDPOINT on gateway."
            return
        }

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

    // MARK: - Connection Test

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            var results: [String] = []

            // 1. VPN check via Guardian /health
            await authManager.checkVPNConnectivity()
            if authManager.isVPNReachable {
                results.append("VPN OK")
            } else {
                results.append("VPN not reachable — check WireGuard")
                testResult = results.joined(separator: "\n")
                isTesting = false
                return
            }

            // 2. Auth check
            do {
                _ = try await authManager.ensureValidToken()
                results.append("Auth OK")
            } catch {
                results.append("Auth failed: \(error.localizedDescription)")
                testResult = results.joined(separator: "\n")
                isTesting = false
                return
            }

            // 3. nexus-core server check
            let transport = TransportManager(deviceConfigStore: deviceConfigStore)
            let client = NexusSyncClient(deviceConfigStore: deviceConfigStore, authManager: authManager, transportManager: transport)
            do {
                let response = try await client.status()
                results.append("Server OK — v\(response.currentVersion)")
            } catch {
                results.append("Server error: \(error.localizedDescription)")
            }

            testResult = results.joined(separator: "\n")
            isTesting = false
        }
    }
}

// MARK: - Share Sheet

private struct WireGuardShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
