import SwiftUI

/// Dashboard showing sync status: last sync time, pending changes, server connectivity, recent conflicts.
struct SyncStatusView: View {
    @EnvironmentObject var syncCoordinator: SyncCoordinator
    @EnvironmentObject var syncStateStore: SyncStateStore
    @EnvironmentObject var deviceConfigStore: DeviceConfigStore

    var body: some View {
        List {
            Section(NSLocalizedString("syncConnectionStatus", comment: "Connection")) {
                HStack {
                    Text(NSLocalizedString("syncServer", comment: "Server"))
                    Spacer()
                    Text(deviceConfigStore.config.serverURL.isEmpty
                         ? NSLocalizedString("syncNotConfigured", comment: "Not configured")
                         : deviceConfigStore.config.serverURL)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(NSLocalizedString("syncDeviceId", comment: "Device ID"))
                    Spacer()
                    Text(deviceConfigStore.config.deviceId.uuidString.prefix(8) + "...")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                HStack {
                    Text(NSLocalizedString("syncCurrentStatus", comment: "Status"))
                    Spacer()
                    statusBadge
                }
            }

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

            Section(NSLocalizedString("syncPendingChanges", comment: "Pending Changes")) {
                HStack {
                    Text(NSLocalizedString("syncQueuedChanges", comment: "Queued changes"))
                    Spacer()
                    Text("\(syncCoordinator.outboundQueue.count)")
                        .foregroundStyle(syncCoordinator.outboundQueue.isEmpty ? .secondary : .orange)
                }
            }

            if !syncStateStore.conflictLog.isEmpty {
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

            if let result = syncCoordinator.lastSyncResult {
                Section(NSLocalizedString("syncLastResult", comment: "Last Result")) {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(NSLocalizedString("syncStatusTitle", comment: "Sync Status"))
    }

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
}
