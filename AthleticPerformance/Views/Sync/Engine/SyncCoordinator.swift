import Foundation
import Combine
import CryptoKit

/// Orchestrates the full sync flow: push local changes, pull remote changes.
/// Wires PatientStore's onPatientChanged callback to the outbound queue via ChangeDetector.
@MainActor
final class SyncCoordinator: ObservableObject {

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case error(String)
    }

    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var lastSyncResult: String?

    let outboundQueue: OutboundQueue
    let versionTracker: EntityVersionTracker
    let syncStateStore: SyncStateStore
    let deviceConfigStore: DeviceConfigStore
    let transportManager: TransportManager

    /// Backward-compatible alias — used by existing code that references connectivityMonitor.
    var connectivityMonitor: TransportManager { transportManager }

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
        transportManager: TransportManager
    ) {
        self.patientStore = patientStore
        self.outboundQueue = outboundQueue
        self.versionTracker = versionTracker
        self.syncStateStore = syncStateStore
        self.deviceConfigStore = deviceConfigStore
        self.client = client
        self.transportManager = transportManager

        // Wire patient changes to the outbound queue
        patientStore.onPatientChanged = { [weak self] newPatient, oldPatient in
            self?.handlePatientChanged(new: newPatient, old: oldPatient)
        }
    }

    // MARK: - Auto Sync

    func startAutoSync() {
        transportManager.startMonitoring()

        // Watch connectivity + queue count — push when server reachable and queue non-empty.
        // Only auto-push after the first manual sync has completed (lastPushAt != nil).
        // The initial bulk sync (thousands of entities) must be user-initiated.
        transportManager.$isServerReachable
            .combineLatest(outboundQueue.$items)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] (reachable, items) in
                guard let self, reachable, !items.isEmpty, self.status == .idle,
                      self.syncStateStore.state.lastPushAt != nil else { return }
                Task { await self.pushChanges() }
            }
            .store(in: &cancellables)

        // Periodic pull every 5 minutes when connected
        pullTimer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.transportManager.isServerReachable, self.status == .idle else { return }
                Task { await self.pullChanges() }
            }
    }

    func stopAutoSync() {
        transportManager.stopMonitoring()
        cancellables.removeAll()
        pullTimer?.cancel()
        pullTimer = nil
        autoSyncTask?.cancel()
        autoSyncTask = nil
    }

    /// Attempt a final push when the app goes to background.
    func pushOnBackground() {
        guard transportManager.isServerReachable, !outboundQueue.isEmpty,
              syncStateStore.state.lastPushAt != nil else { return }
        autoSyncTask = Task {
            await pushChanges()
        }
    }

    // MARK: - Patient Change → Outbound Queue

    private func handlePatientChanged(new: Patient, old: Patient?) {
        var allChanges = ChangeDetector.detectChanges(old: old, new: new, versionTracker: versionTracker)

        if let store = patientStore {
            // Extract any new change log entries for this patient
            let changeLogChanges = extractNewChangeLogs(for: new.id, patientStore: store)
            allChanges.append(contentsOf: changeLogChanges)

            // Extract invoices from separate files (source of truth, not therapy.invoices)
            let invoiceChanges = extractInvoiceChanges(for: new.id, patientStore: store)
            allChanges.append(contentsOf: invoiceChanges)
        }

        guard !allChanges.isEmpty else { return }
        outboundQueue.enqueueAll(allChanges)
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
        // First-time sync: clear any stale queue and rebuild fresh
        if syncStateStore.state.lastPushAt == nil {
            outboundQueue.clear()
            enqueueAllForInitialSync()
        } else {
            // Always re-push practice info (small payload, server upserts)
            // to ensure latest fields (e.g. startAddress) reach the DWH.
            enqueuePracticeInfo()
        }

        // Disconnect patient change callback during sync to prevent
        // async operations (geocoding, etc.) from re-enqueuing items.
        let savedCallback = patientStore?.onPatientChanged
        patientStore?.onPatientChanged = nil

        await pushChanges()
        await pullChanges()

        patientStore?.onPatientChanged = savedCallback
        syncStateStore.state.lastSyncAt = Date()
        syncStateStore.state.pendingChangeCount = outboundQueue.count
        syncStateStore.saveState()
    }

    /// Re-enqueue practice info so updated fields reach the server.
    private func enqueuePracticeInfo() {
        let practiceEntities = EntityExtractor.extractPracticeInfo(AppGlobals.shared.practiceInfo)
        var changes: [QueuedChange] = []
        for entity in practiceEntities {
            changes.append(QueuedChange(
                entityType: entity.entityType,
                entityId: entity.entityId,
                patientId: entity.patientId,
                dataCategory: entity.dataCategory,
                data: entity.data,
                operation: "update"
            ))
        }
        if !changes.isEmpty {
            outboundQueue.enqueueAll(changes)
        }
    }

    /// Enqueues all existing patients for initial sync (first-time push).
    /// Call this once when the device has never synced before.
    func enqueueAllForInitialSync() {
        guard let patientStore else { return }
        let patients = patientStore.patients
        guard !patients.isEmpty else { return }

        var allChanges: [QueuedChange] = []

        // Practice info (practice, therapists, services) — parameter data for DWH dimensions
        let practiceEntities = EntityExtractor.extractPracticeInfo(AppGlobals.shared.practiceInfo)
        for entity in practiceEntities {
            allChanges.append(QueuedChange(
                entityType: entity.entityType,
                entityId: entity.entityId,
                patientId: entity.patientId,
                dataCategory: entity.dataCategory,
                data: entity.data,
                operation: "create"
            ))
        }

        for patient in patients {
            let entities = EntityExtractor.extractAll(from: patient)
            for entity in entities {
                allChanges.append(QueuedChange(
                    entityType: entity.entityType,
                    entityId: entity.entityId,
                    patientId: entity.patientId,
                    dataCategory: entity.dataCategory,
                    data: entity.data,
                    operation: "create"
                ))
            }

            // Include invoices from separate files (source of truth)
            let invoicesDir = patientStore.invoicesDirectoryURL(for: patient.id)
            let invoiceEntities = EntityExtractor.extractInvoicesFromFiles(
                invoicesDirectory: invoicesDir, patientId: patient.id
            )
            for entity in invoiceEntities {
                allChanges.append(QueuedChange(
                    entityType: entity.entityType,
                    entityId: entity.entityId,
                    patientId: entity.patientId,
                    dataCategory: entity.dataCategory,
                    data: entity.data,
                    operation: "create"
                ))
            }

            // Include all change log entries (initial sync — no marker, send everything)
            let changesDir = patientStore.changesDirectoryURL(for: patient.id)
            let (changeLogEntities, processedFiles) = EntityExtractor.extractChangeLogs(
                from: changesDir, patientId: patient.id
            )
            for entity in changeLogEntities {
                allChanges.append(QueuedChange(
                    entityType: entity.entityType,
                    entityId: entity.entityId,
                    patientId: entity.patientId,
                    dataCategory: entity.dataCategory,
                    data: entity.data,
                    operation: "create"
                ))
            }
            if let lastFile = processedFiles.last {
                syncStateStore.state.syncedChangeLogMarkers[patient.id.uuidString] = lastFile
            }
        }

        // Availability slots — load directly from file (weak store may be nil)
        if let therapistId = AppGlobals.shared.therapistId {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let tempStore = AvailabilityStore(therapistId: therapistId.uuidString, baseDirectory: docsDir)
            if !tempStore.slots.isEmpty {
                let availEntities = EntityExtractor.extractAvailability(slots: tempStore.slots, therapistId: therapistId)
                for entity in availEntities {
                    allChanges.append(QueuedChange(
                        entityType: entity.entityType,
                        entityId: entity.entityId,
                        patientId: entity.patientId,
                        dataCategory: entity.dataCategory,
                        data: entity.data,
                        operation: "create"
                    ))
                }
            }
        }

        // Reference parameters (bundled JSON files for DWH dim_parameter)
        let refEntities = EntityExtractor.extractReferenceParameters()
        for entity in refEntities {
            allChanges.append(QueuedChange(
                entityType: entity.entityType,
                entityId: entity.entityId,
                patientId: entity.patientId,
                dataCategory: entity.dataCategory,
                data: entity.data,
                operation: "create"
            ))
        }

        outboundQueue.enqueueAll(allChanges)
        syncStateStore.state.pendingChangeCount = outboundQueue.count
        syncStateStore.saveState()
    }

    // MARK: - Change Log Extraction

    private func extractNewChangeLogs(for patientId: UUID, patientStore: PatientStore) -> [QueuedChange] {
        let changesDir = patientStore.changesDirectoryURL(for: patientId)
        let marker = syncStateStore.state.syncedChangeLogMarkers[patientId.uuidString]

        let (entities, processedFiles) = EntityExtractor.extractChangeLogs(
            from: changesDir, patientId: patientId, afterFile: marker
        )

        guard !entities.isEmpty else { return [] }

        if let lastFile = processedFiles.last {
            syncStateStore.state.syncedChangeLogMarkers[patientId.uuidString] = lastFile
        }

        return entities.map { entity in
            QueuedChange(
                entityType: entity.entityType,
                entityId: entity.entityId,
                patientId: entity.patientId,
                dataCategory: entity.dataCategory,
                data: entity.data,
                operation: "create"
            )
        }
    }

    // MARK: - Invoice Extraction

    private func extractInvoiceChanges(for patientId: UUID, patientStore: PatientStore) -> [QueuedChange] {
        let invoicesDir = patientStore.invoicesDirectoryURL(for: patientId)
        let entities = EntityExtractor.extractInvoicesFromFiles(
            invoicesDirectory: invoicesDir, patientId: patientId
        )

        // Enqueue all invoice entities — the outbound queue deduplicates by entityId,
        // and the server upserts, so re-sending unchanged invoices is safe.
        return entities.map { entity in
            QueuedChange(
                entityType: entity.entityType,
                entityId: entity.entityId,
                patientId: entity.patientId,
                dataCategory: entity.dataCategory,
                data: entity.data,
                operation: versionTracker.operation(for: entity.entityId)
            )
        }
    }

    // MARK: - Push

    private let pushBatchSize = 500

    func pushChanges() async {
        let allItems = outboundQueue.items
        guard !allItems.isEmpty else { return }

        status = .syncing

        var totalAccepted = 0
        var totalConflicts = 0
        var totalErrors = 0
        var totalUploaded = 0
        var totalUploadFailed = 0
        var lastBatchError: String?
        let batchCount = (allItems.count + pushBatchSize - 1) / pushBatchSize

        for batchIndex in 0..<batchCount {
            let start = batchIndex * pushBatchSize
            let end = min(start + pushBatchSize, allItems.count)
            let batchItems = Array(allItems[start..<end])

            let pushChanges: [SyncPushChange] = batchItems.map { item in
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

            let manifests = computeManifests(for: pushChanges)
            let (attachmentRefs, attachmentPaths) = buildAttachmentRefs(from: pushChanges)

            let request = SyncPushRequest(
                deviceId: deviceConfigStore.config.deviceId,
                syncId: UUID(),
                clientTimestamp: Date(),
                lastPullVersion: syncStateStore.state.lastPullVersion,
                changes: pushChanges,
                attachments: attachmentRefs,
                manifests: manifests.isEmpty ? nil : manifests
            )

            do {
                let response = try await client.push(request)

                // Process accepted changes
                let acceptedIds = Set(response.accepted.map(\.entityId))
                for accepted in response.accepted {
                    versionTracker.updateVersion(
                        entityId: accepted.entityId,
                        entityType: accepted.entityType,
                        serverVersion: accepted.serverVersion
                    )
                }
                outboundQueue.markSynced(entityIds: acceptedIds)

                // Process conflicts — remove from queue regardless of resolution
                for conflict in response.conflicts {
                    if conflict.resolution == "server_wins" {
                        applyServerWinsConflict(conflict)
                    }
                    versionTracker.updateVersion(
                        entityId: conflict.entityId,
                        entityType: conflict.entityType,
                        serverVersion: conflict.serverVersion
                    )
                    outboundQueue.markSynced(entityIds: [conflict.entityId])
                }

                // Re-queue errors for retry
                let errorIds = Set(response.errors.map(\.entityId))
                let failedItems = batchItems.filter { errorIds.contains($0.entityId) }
                outboundQueue.requeue(failedItems)

                totalAccepted += response.accepted.count
                totalConflicts += response.conflicts.count
                totalErrors += response.errors.count

                // Upload pending attachments per batch
                if !response.pendingUploads.isEmpty {
                    let uploadResults = await AttachmentUploader.uploadPending(response.pendingUploads, relativePaths: attachmentPaths, client: client)
                    totalUploaded += uploadResults.filter(\.success).count
                    totalUploadFailed += uploadResults.filter({ !$0.success }).count
                }

            } catch {
                // Log the error but continue with remaining batches
                totalErrors += batchItems.count
                lastBatchError = error.localizedDescription
            }
        }

        // Update state after all batches
        syncStateStore.state.lastPushAt = Date()
        syncStateStore.state.pendingChangeCount = outboundQueue.count
        syncStateStore.saveState()

        var result = "Push: \(totalAccepted) accepted, \(totalErrors) errors"
        if totalUploaded + totalUploadFailed > 0 {
            result += " | Uploads: \(totalUploaded) ok, \(totalUploadFailed) failed"
        }
        lastSyncResult = result

        if let batchError = lastBatchError {
            status = .error("Push partially failed: \(batchError)")
        } else {
            status = .idle
        }
    }

    // MARK: - Pull

    func pullChanges() async {
        status = .syncing

        // Temporarily disconnect patient change callback to prevent
        // pulled changes from being re-enqueued into the outbound queue.
        let savedCallback = patientStore?.onPatientChanged
        patientStore?.onPatientChanged = nil

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

            if totalChanges > 0 {
                let pullInfo = "\(totalChanges) received"
                if let existing = lastSyncResult {
                    lastSyncResult = existing + ", " + pullInfo
                } else {
                    lastSyncResult = pullInfo
                }
            }

            // If nothing happened at all, set a simple completion message
            if lastSyncResult == nil {
                lastSyncResult = "up_to_date"
            }
            patientStore?.onPatientChanged = savedCallback
            status = .idle

        } catch {
            patientStore?.onPatientChanged = savedCallback
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
            // Detail entity types that don't need merging into patient.json
            // (they are extracted from the patient structure for the DWH but
            // don't exist as standalone entities on the iPad)
            switch change.entityType {
            case .clinicalObservation, .appliedTreatment, .diagnosisTreatment,
                 .invoiceItem, .changeLog, .documentMeta:
                return
            default:
                break
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

    // MARK: - Manifest Computation

    private func computeManifests(for changes: [SyncPushChange]) -> [SyncManifest] {
        // Group changes by patientId (skip nil — e.g. availability slots)
        var grouped: [UUID: [SyncPushChange]] = [:]
        for change in changes {
            guard let patientId = change.patientId else { continue }
            grouped[patientId, default: []].append(change)
        }

        return grouped.map { (patientId, patientChanges) in
            // Per entity-type counts
            var typeCounts: [String: Int] = [:]
            for change in patientChanges {
                typeCounts[change.entityType.rawValue, default: 0] += 1
            }

            let entityIds = patientChanges.map(\.entityId)
            let checksum = computeContentChecksum(for: patientChanges)

            return SyncManifest(
                patientId: patientId,
                entityCount: patientChanges.count,
                entityTypeCounts: typeCounts,
                entityIds: entityIds,
                contentChecksum: checksum
            )
        }
    }

    /// Builds SyncAttachmentRef entries for document_meta entities that have files on disk.
    /// Returns refs and a mapping of entityId → relativePath for the uploader.
    private func buildAttachmentRefs(from changes: [SyncPushChange]) -> ([SyncAttachmentRef], [UUID: String]) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fm = FileManager.default
        var refs: [SyncAttachmentRef] = []
        var paths: [UUID: String] = [:]

        for change in changes where change.entityType == .documentMeta {
            let data = change.data.mapValues(\.value)
            guard let filename = data["filename"] as? String,
                  let relativePath = data["relativePath"] as? String else { continue }

            let fileURL = documentsURL.appendingPathComponent(relativePath)
            guard fm.fileExists(atPath: fileURL.path),
                  let fileData = try? Data(contentsOf: fileURL) else { continue }

            let contentType = AttachmentUploader.mimeType(for: filename)
            let checksum = AttachmentUploader.sha256(data: fileData)

            refs.append(SyncAttachmentRef(
                entityId: change.entityId,
                filename: filename,
                contentType: contentType,
                sizeBytes: fileData.count,
                checksum: checksum
            ))
            paths[change.entityId] = relativePath
        }

        return (refs, paths)
    }

    private func computeContentChecksum(for changes: [SyncPushChange]) -> String {
        // Algorithm (must match server side):
        // 1. For each change, serialize its data dict with sorted keys, compact
        // 2. Sort the JSON strings lexicographically
        // 3. Join with "\n"
        // 4. SHA-256 hash → lowercase hex

        var jsonStrings: [String] = []
        for change in changes {
            let rawDict = change.data.mapValues(\.value)
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: rawDict,
                options: [.sortedKeys, .withoutEscapingSlashes]
            ),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                jsonStrings.append(jsonStr)
            }
        }
        jsonStrings.sort()
        let concatenated = jsonStrings.joined(separator: "\n")
        let data = Data(concatenated.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
