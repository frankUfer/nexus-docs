import SwiftUI

/// Unified sync view: device status, sync trigger, connection test, auth status, and reset provisioning.
struct SyncStatusView: View {
    @EnvironmentObject var syncCoordinator: SyncCoordinator
    @EnvironmentObject var syncStateStore: SyncStateStore
    @EnvironmentObject var deviceConfigStore: DeviceConfigStore
    @EnvironmentObject var authManager: AuthManager

    @State private var isSyncing = false
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var showResetConfirmation = false
    @State private var showResetSyncConfirmation = false

    var body: some View {
        List {
            if deviceConfigStore.config.isProvisioned {
                deviceStatusSection
            }

            syncSection

            lastSyncSection

            pendingChangesSection

            if !syncStateStore.conflictLog.isEmpty {
                conflictsSection
            }

            connectionTestSection

            authSection

            if deviceConfigStore.config.isProvisioned {
                resetSyncSection
                resetSection
            }
        }
        .navigationTitle(NSLocalizedString("syncSynchronisation", comment: "Synchronisation"))
        .alert(
            NSLocalizedString("syncResetConfirmTitle", comment: "Reset provisioning?"),
            isPresented: $showResetConfirmation
        ) {
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
            Button(NSLocalizedString("syncResetConfirmButton", comment: "Reset"), role: .destructive) {
                deviceConfigStore.config = DeviceConfig.default()
                deviceConfigStore.save()
                authManager.clearAll()
            }
        } message: {
            Text(NSLocalizedString("syncResetConfirmMessage", comment: "Reset message"))
        }
        .alert(
            NSLocalizedString("syncResetSyncStateTitle", comment: "Reset sync state?"),
            isPresented: $showResetSyncConfirmation
        ) {
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
            Button(NSLocalizedString("syncResetSyncStateButton", comment: "Reset & Sync"), role: .destructive) {
                syncStateStore.resetSyncState()
                _ = syncCoordinator.outboundQueue.dequeueAll()
                isSyncing = true
                Task {
                    await syncCoordinator.fullSync()
                    isSyncing = false
                }
            }
        } message: {
            Text(NSLocalizedString("syncResetSyncStateMessage", comment: "Reset sync state message"))
        }
    }

    // MARK: - Device Status

    private var deviceStatusSection: some View {
        Section(NSLocalizedString("syncDeviceStatus", comment: "Device Status")) {
            LabeledContent(NSLocalizedString("syncDevice", comment: "Device"),
                           value: deviceConfigStore.config.deviceName)
            LabeledContent(NSLocalizedString("syncServer", comment: "Server"),
                           value: deviceConfigStore.config.serverURL)
            LabeledContent(NSLocalizedString("syncTier", comment: "Tier"),
                           value: deviceConfigStore.config.deploymentTier.capitalized)
            if deviceConfigStore.config.isFullTier {
                LabeledContent("Guardian", value: deviceConfigStore.config.guardianURL)
            }
            HStack {
                Text(NSLocalizedString("syncProvisioned", comment: "Provisioned"))
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        Section(NSLocalizedString("synchronization", comment: "Sync")) {
            HStack {
                Text(NSLocalizedString("syncCurrentStatus", comment: "Status"))
                Spacer()
                statusBadge
            }

            Button {
                isSyncing = true
                Task {
                    await syncCoordinator.fullSync()
                    isSyncing = false
                }
            } label: {
                Label(NSLocalizedString("syncStartSync", comment: "Start Sync"),
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing)

            if let result = syncCoordinator.lastSyncResult {
                GroupBox {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Last Sync

    private var lastSyncSection: some View {
        Section(NSLocalizedString("syncLastSync", comment: "Last Sync")) {
            HStack {
                Text(NSLocalizedString("syncLastSyncTime", comment: "Last sync"))
                Spacer()
                if let lastSync = syncStateStore.state.lastSyncAt {
                    Text(lastSync, style: .relative)
                        .foregroundStyle(.secondary)
                } else {
                    Text(NSLocalizedString("syncNever", comment: "Never"))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(NSLocalizedString("syncLastPush", comment: "Last push"))
                Spacer()
                if let lastPush = syncStateStore.state.lastPushAt {
                    Text(lastPush, style: .relative)
                        .foregroundStyle(.secondary)
                } else {
                    Text(NSLocalizedString("syncNever", comment: "Never"))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(NSLocalizedString("syncPullVersion", comment: "Pull version"))
                Spacer()
                Text("\(syncStateStore.state.lastPullVersion)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pending Changes

    private var pendingChangesSection: some View {
        Section(NSLocalizedString("syncPendingChanges", comment: "Pending Changes")) {
            HStack {
                Text(NSLocalizedString("syncQueuedChanges", comment: "Queued changes"))
                Spacer()
                Text("\(syncCoordinator.outboundQueue.count)")
                    .foregroundStyle(syncCoordinator.outboundQueue.isEmpty ? Color.secondary : Color.orange)
            }
        }
    }

    // MARK: - Conflicts

    private var conflictsSection: some View {
        Section(NSLocalizedString("syncRecentConflicts", comment: "Recent Conflicts")) {
            ForEach(syncStateStore.conflictLog.suffix(10).reversed()) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.entityType.rawValue)
                            .font(.caption.bold())
                        Spacer()
                        Text(entry.resolution)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text(entry.entityId.uuidString.prefix(8) + "...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Connection Test

    private var connectionTestSection: some View {
        Section(NSLocalizedString("syncTestConnection", comment: "Connection Test")) {
            Button {
                testConnection()
            } label: {
                if isTesting {
                    ProgressView()
                } else {
                    Label(NSLocalizedString("syncTestButton", comment: "Test Connection"),
                          systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .disabled(isTesting || deviceConfigStore.config.guardianURL.isEmpty)

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("Server OK") ? .green : .orange)
            }
        }
    }

    // MARK: - Authentication

    private var authSection: some View {
        Section(NSLocalizedString("syncAuthentication", comment: "Authentication")) {
            HStack {
                Text(NSLocalizedString("syncAuthStatus", comment: "Status"))
                Spacer()
                authStatusBadge
            }
        }
    }

    // MARK: - Reset Sync State

    private var resetSyncSection: some View {
        Section {
            Button(NSLocalizedString("syncResetSyncState", comment: "Reset Sync State"), role: .destructive) {
                showResetSyncConfirmation = true
            }
            .disabled(isSyncing)
        } footer: {
            Text(NSLocalizedString("syncResetSyncStateFooter", comment: "Reset sync state footer"))
        }
    }

    // MARK: - Reset Provisioning

    private var resetSection: some View {
        Section {
            Button(NSLocalizedString("syncResetProvisioning", comment: "Reset Provisioning"), role: .destructive) {
                showResetConfirmation = true
            }
            .font(.caption)
        } footer: {
            Text(NSLocalizedString("syncResetFooter", comment: "Reset footer"))
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch syncCoordinator.status {
        case .idle:
            Label(NSLocalizedString("syncIdle", comment: "Idle"), systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .font(.caption)
        case .pushing:
            Label(NSLocalizedString("syncPushing", comment: "Pushing..."), systemImage: "arrow.up.circle")
                .foregroundStyle(.blue)
                .font(.caption)
        case .pulling:
            Label(NSLocalizedString("syncPulling", comment: "Pulling..."), systemImage: "arrow.down.circle")
                .foregroundStyle(.blue)
                .font(.caption)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.caption)
                .lineLimit(1)
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

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            var results: [String] = []

            await authManager.checkVPNConnectivity()
            if authManager.isVPNReachable {
                results.append("VPN OK")
            } else {
                results.append("VPN not reachable — check WireGuard")
                testResult = results.joined(separator: "\n")
                isTesting = false
                return
            }

            do {
                _ = try await authManager.ensureValidToken()
                results.append("Auth OK")
            } catch {
                results.append("Auth failed: \(error.localizedDescription)")
                testResult = results.joined(separator: "\n")
                isTesting = false
                return
            }

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
