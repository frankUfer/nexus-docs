import SwiftUI

/// Sync settings: server URL, device name, device ID, JWT token management, connection test.
struct SyncSettingsView: View {
    @EnvironmentObject var deviceConfigStore: DeviceConfigStore

    @State private var serverURL: String = ""
    @State private var deviceName: String = ""
    @State private var tokenInput: String = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section(NSLocalizedString("syncServerConfig", comment: "Server Configuration")) {
                TextField(NSLocalizedString("syncServerURL", comment: "Server URL"), text: $serverURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onAppear { serverURL = deviceConfigStore.config.serverURL }
                    .onSubmit { saveServerURL() }

                TextField(NSLocalizedString("syncDeviceName", comment: "Device Name"), text: $deviceName)
                    .onAppear { deviceName = deviceConfigStore.config.deviceName }
                    .onSubmit { saveDeviceName() }
            }

            Section(NSLocalizedString("syncDeviceInfo", comment: "Device Info")) {
                HStack {
                    Text(NSLocalizedString("syncDeviceId", comment: "Device ID"))
                    Spacer()
                    Text(deviceConfigStore.config.deviceId.uuidString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack {
                    Text(NSLocalizedString("syncRegistered", comment: "Registered"))
                    Spacer()
                    Image(systemName: deviceConfigStore.config.isRegistered ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(deviceConfigStore.config.isRegistered ? .green : .red)
                }
            }

            Section(NSLocalizedString("syncAuthentication", comment: "Authentication")) {
                HStack {
                    Text(NSLocalizedString("syncJWTToken", comment: "JWT Token"))
                    Spacer()
                    if KeychainHelper.loadToken() != nil {
                        Label(NSLocalizedString("syncTokenStored", comment: "Stored"), systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(NSLocalizedString("syncNoToken", comment: "Not set"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                SecureField(NSLocalizedString("syncEnterToken", comment: "Enter JWT token"), text: $tokenInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Button(NSLocalizedString("syncSaveToken", comment: "Save Token")) {
                        guard !tokenInput.isEmpty else { return }
                        KeychainHelper.saveToken(tokenInput)
                        tokenInput = ""
                    }
                    .disabled(tokenInput.isEmpty)

                    Spacer()

                    Button(NSLocalizedString("syncDeleteToken", comment: "Delete Token"), role: .destructive) {
                        KeychainHelper.deleteToken()
                    }
                }
            }

            Section(NSLocalizedString("syncTestConnection", comment: "Test Connection")) {
                Button {
                    testConnection()
                } label: {
                    if isTesting {
                        ProgressView()
                    } else {
                        Label(NSLocalizedString("syncTestButton", comment: "Test Connection"), systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .disabled(isTesting || serverURL.isEmpty)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("OK") ? .green : .red)
                }
            }

            Section {
                Button(NSLocalizedString("syncSaveSettings", comment: "Save Settings")) {
                    saveServerURL()
                    saveDeviceName()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(NSLocalizedString("syncSettingsTitle", comment: "Sync Settings"))
    }

    private func saveServerURL() {
        deviceConfigStore.config.serverURL = serverURL
        deviceConfigStore.save()
    }

    private func saveDeviceName() {
        deviceConfigStore.config.deviceName = deviceName
        deviceConfigStore.save()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let client = NexusSyncClient(deviceConfigStore: deviceConfigStore)
        Task {
            do {
                let response = try await client.status()
                await MainActor.run {
                    testResult = "OK — Server v\(response.currentVersion), \(ISO8601DateFormatter.syncFormatter.string(from: response.serverTimestamp))"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}
