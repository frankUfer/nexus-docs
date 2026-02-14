import SwiftUI

/// Manual sync trigger with progress indicator and results display.
struct SyncNowView: View {
    @EnvironmentObject var syncCoordinator: SyncCoordinator

    @State private var isSyncing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status icon
            Group {
                switch syncCoordinator.status {
                case .idle:
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                case .pushing, .pulling:
                    ProgressView()
                        .scaleEffect(2)
                case .error:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                }
            }
            .frame(height: 80)

            // Status text
            switch syncCoordinator.status {
            case .idle:
                Text(NSLocalizedString("syncReady", comment: "Ready to sync"))
                    .font(.headline)
            case .pushing:
                Text(NSLocalizedString("syncPushingData", comment: "Pushing local changes..."))
                    .font(.headline)
            case .pulling:
                Text(NSLocalizedString("syncPullingData", comment: "Pulling server changes..."))
                    .font(.headline)
            case .error(let msg):
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Pending changes info
            let pending = syncCoordinator.outboundQueue.count
            if pending > 0 {
                Text(String(format: NSLocalizedString("syncPendingCount", comment: "%d pending changes"), pending))
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }

            // Sync button
            Button {
                isSyncing = true
                Task {
                    await syncCoordinator.fullSync()
                    isSyncing = false
                }
            } label: {
                Label(NSLocalizedString("syncStartSync", comment: "Start Sync"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing)

            // Last result
            if let result = syncCoordinator.lastSyncResult {
                GroupBox {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .navigationTitle(NSLocalizedString("syncNowTitle", comment: "Sync Now"))
    }
}
