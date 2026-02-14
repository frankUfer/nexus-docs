import Foundation
import Combine

/// Orchestrates the full sync flow: push local changes, pull remote changes.
/// Wires PatientStore's onPatientChanged callback to the outbound queue via ChangeDetector.
@MainActor
final class SyncCoordinator: ObservableObject {

    enum SyncStatus: Equatable {
        case idle
        case pushing
        case pulling
        case error(String)
    }

    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var lastSyncResult: String?

    let outboundQueue: OutboundQueue
    let versionTracker: EntityVersionTracker
    let syncStateStore: SyncStateStore
    let deviceConfigStore: DeviceConfigStore
    let connectivityMonitor: ConnectivityMonitor

    private let client: NexusSyncClient
    private weak var patientStore: PatientStore?
    private weak var availabilityStore: AvailabilityStore?
    private var lastAvailabilitySnapshot: [AvailabilitySlot]?
    private var cancellables = Set<AnyCancellable>()
    private var autoSyncTask: Task<Void, Never>?
    private var pullTimer: AnyCancellable?

    init(
        patientStore: PatientStore,
        outboundQueue: OutboundQueue,
        versionTracker: EntityVersionTracker,
        syncStateStore: SyncStateStore,
        deviceConfigStore: DeviceConfigStore,
        client: NexusSyncClient,
        connectivityMonitor: ConnectivityMonitor
    ) {
        self.patientStore = patientStore
        self.outboundQueue = outboundQueue
        self.versionTracker = versionTracker
        self.syncStateStore = syncStateStore
        self.deviceConfigStore = deviceConfigStore
        self.client = client
        self.connectivityMonitor = connectivityMonitor

        // Wire patient changes to the outbound queue
        patientStore.onPatientChanged = { [weak self] newPatient, oldPatient in
            self?.handlePatientChanged(new: newPatient, old: oldPatient)
        }
    }

    // MARK: - Auto Sync

    func startAutoSync() {
        connectivityMonitor.startMonitoring()

        // Watch connectivity + queue count — push when server reachable and queue non-empty
        connectivityMonitor.$isServerReachable
            .combineLatest(outboundQueue.$items)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] (reachable, items) in
                guard let self, reachable, !items.isEmpty, self.status == .idle else { return }
                Task { await self.pushChanges() }
            }
            .store(in: &cancellables)

        // Periodic pull every 5 minutes when connected
        pullTimer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.connectivityMonitor.isServerReachable, self.status == .idle else { return }
                Task { await self.pullChanges() }
            }
    }

    func stopAutoSync() {
        connectivityMonitor.stopMonitoring()
        cancellables.removeAll()
        pullTimer?.cancel()
        pullTimer = nil
        autoSyncTask?.cancel()
        autoSyncTask = nil
    }

    /// Attempt a final push when the app goes to background.
    func pushOnBackground() {
        guard connectivityMonitor.isServerReachable, !outboundQueue.isEmpty else { return }
        autoSyncTask = Task {
            await pushChanges()
        }
    }

    // MARK: - Patient Change → Outbound Queue

    private func handlePatientChanged(new: Patient, old: Patient?) {
        let changes = ChangeDetector.detectChanges(old: old, new: new, versionTracker: versionTracker)
        guard !changes.isEmpty else { return }
        outboundQueue.enqueueAll(changes)
        syncStateStore.state.pendingChangeCount = outboundQueue.count
        syncStateStore.saveState()
    }

    // MARK: - Availability Sync

    func wireAvailabilityStore(_ store: AvailabilityStore) {
        self.availabilityStore = store
        self.lastAvailabilitySnapshot = store.slots

        store.onAvailabilityChanged = { [weak self] newSlots, therapistId in
            self?.handleAvailabilityChanged(new: newSlots, therapistId: therapistId)
        }
    }

    private func handleAvailabilityChanged(new: [AvailabilitySlot], therapistId: UUID) {
        let changes = ChangeDetector.detectAvailabilityChanges(
            old: lastAvailabilitySnapshot,
            new: new,
            therapistId: therapistId,
            versionTracker: versionTracker
        )
        lastAvailabilitySnapshot = new
        guard !changes.isEmpty else { return }
        outboundQueue.enqueueAll(changes)
        syncStateStore.state.pendingChangeCount = outboundQueue.count
        syncStateStore.saveState()
    }

    private func applyAvailabilityChange(_ change: SyncPullChange) {
        guard let store = availabilityStore else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: change.data.mapValues(\.value)
        ),
              let slot = try? decoder.decode(AvailabilitySlot.self, from: jsonData) else { return }

        // Temporarily disconnect callback to avoid re-enqueueing pulled changes
        let savedCallback = store.onAvailabilityChanged
        store.onAvailabilityChanged = nil
        store.addOrUpdate(slot)
        store.save()
        store.onAvailabilityChanged = savedCallback
        lastAvailabilitySnapshot = store.slots
    }

    // MARK: - Full Sync

    func fullSync() async {
        await pushChanges()
        await pullChanges()
        syncStateStore.state.lastSyncAt = Date()
        syncStateStore.saveState()
    }

    // MARK: - Push

    func pushChanges() async {
        let items = outboundQueue.items
        guard !items.isEmpty else { return }

        status = .pushing

        let pushChanges: [SyncPushChange] = items.map { item in
            SyncPushChange(
                dataCategory: item.dataCategory,
                entityType: item.entityType,
                entityId: item.entityId,
                patientId: item.patientId,
                operation: item.operation,
                version: versionTracker.version(for: item.entityId),
                data: item.data,
                clientModifiedAt: item.queuedAt
            )
        }

        let request = SyncPushRequest(
            deviceId: deviceConfigStore.config.deviceId,
            syncId: UUID(),
            clientTimestamp: Date(),
            lastPullVersion: syncStateStore.state.lastPullVersion,
            changes: pushChanges,
            attachments: [] // Attachments handled separately in Phase 6
        )

        do {
            let response = try await client.push(request)

            // Process accepted changes — update version tracker, remove from queue
            let acceptedIds = Set(response.accepted.map(\.entityId))
            for accepted in response.accepted {
                versionTracker.updateVersion(
                    entityId: accepted.entityId,
                    entityType: accepted.entityType,
                    serverVersion: accepted.serverVersion
                )
            }
            outboundQueue.markSynced(entityIds: acceptedIds)

            // Process conflicts — log them
            for conflict in response.conflicts {
                syncStateStore.addConflict(ConflictLogEntry(
                    date: Date(),
                    entityType: conflict.entityType,
                    entityId: conflict.entityId,
                    resolution: conflict.resolution,
                    serverData: conflict.serverData,
                    clientData: conflict.clientData
                ))

                // For server_wins conflicts (parameters), apply server data locally
                if conflict.resolution == "server_wins" {
                    applyServerWinsConflict(conflict)
                }

                // For client_wins, the server accepted our data — treat as accepted
                if conflict.resolution == "client_wins" {
                    versionTracker.updateVersion(
                        entityId: conflict.entityId,
                        entityType: conflict.entityType,
                        serverVersion: conflict.serverVersion
                    )
                    outboundQueue.markSynced(entityIds: [conflict.entityId])
                }
            }

            // Process errors — re-queue for retry
            let errorIds = Set(response.errors.map(\.entityId))
            let failedItems = items.filter { errorIds.contains($0.entityId) }
            outboundQueue.requeue(failedItems)

            // Update state
            syncStateStore.state.lastPushAt = Date()
            syncStateStore.state.pendingChangeCount = outboundQueue.count
            syncStateStore.saveState()

            // Upload pending attachments
            if !response.pendingUploads.isEmpty {
                let uploadResults = await AttachmentUploader.uploadPending(response.pendingUploads, client: client)
                let uploaded = uploadResults.filter(\.success).count
                let failed = uploadResults.count - uploaded
                lastSyncResult = "Push: \(response.accepted.count) accepted, \(response.conflicts.count) conflicts, \(response.errors.count) errors | Uploads: \(uploaded) ok, \(failed) failed"
            } else {
                lastSyncResult = "Push: \(response.accepted.count) accepted, \(response.conflicts.count) conflicts, \(response.errors.count) errors"
            }
            status = .idle

        } catch {
            status = .error("Push failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Pull

    func pullChanges() async {
        status = .pulling

        do {
            var sinceVersion = syncStateStore.state.lastPullVersion
            var totalChanges = 0

            repeat {
                let response = try await client.pull(sinceVersion: sinceVersion)
                totalChanges += response.changes.count

                for change in response.changes {
                    await applyPulledChange(change)
                    versionTracker.updateFromPull(
                        entityId: change.entityId,
                        entityType: change.entityType,
                        version: change.version
                    )

                    // Download attachments if present
                    if let attachments = change.attachments, !attachments.isEmpty {
                        _ = await AttachmentDownloader.downloadAttachments(for: change, client: client)
                    }
                }

                sinceVersion = response.nextVersion ?? response.currentVersion

                if !response.hasMore {
                    syncStateStore.state.lastPullVersion = response.currentVersion
                    syncStateStore.saveState()
                    break
                }
            } while true

            let pullInfo = "Pull: \(totalChanges) changes applied"
            if let existing = lastSyncResult {
                lastSyncResult = existing + " | " + pullInfo
            } else {
                lastSyncResult = pullInfo
            }
            status = .idle

        } catch {
            status = .error("Pull failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Apply Pulled Change

    private func applyPulledChange(_ change: SyncPullChange) async {
        switch change.dataCategory {
        case .parameter:
            if ParameterSyncHandler.apply(change: change) {
                ParameterSyncHandler.reloadParameters()
            }

        case .masterData, .transactionalData:
            if change.entityType == .availability {
                applyAvailabilityChange(change)
                return
            }
            guard let patientStore else { return }
            _ = await PatientSyncHandler.apply(change: change, patientStore: patientStore)
        }
    }

    // MARK: - Server Wins Conflict Application

    private func applyServerWinsConflict(_ conflict: SyncConflictInfo) {
        // For parameter conflicts where server wins, the server data overrides.
        // Build a synthetic pull change and apply via ParameterSyncHandler.
        let syntheticChange = SyncPullChange(
            dataCategory: conflict.dataCategory,
            entityType: conflict.entityType,
            entityId: conflict.entityId,
            patientId: nil,
            operation: "update",
            version: conflict.serverVersion,
            data: conflict.serverData,
            serverModifiedAt: Date(),
            attachments: nil
        )
        if ParameterSyncHandler.apply(change: syntheticChange) {
            ParameterSyncHandler.reloadParameters()
        }

        // Remove the entity from the outbound queue since the server rejected it.
        outboundQueue.markSynced(entityIds: [conflict.entityId])
    }
}
