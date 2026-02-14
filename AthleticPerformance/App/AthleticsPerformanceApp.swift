//
//  AthleticsPerformanceApp.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.03.25.
//

import AVFoundation
import SwiftUI
import ZipArchive

@main
struct AthleticsPerformanceApp: App {
    /// The patient data store, shared via the environment.
    @StateObject private var patientStore = PatientStore()

    /// The global navigation state store.
    @StateObject private var navigationStore = AppNavigationStore()

    // Sync infrastructure
    @StateObject private var deviceConfigStore = DeviceConfigStore()
    @StateObject private var syncStateStore = SyncStateStore()
    @StateObject private var outboundQueue = OutboundQueue()
    @StateObject private var versionTracker = EntityVersionTracker()

    /// Indicates whether initial setup is complete.
    @State private var isSetupComplete = false

    /// Indicates whether loading was successful.
    @State private var isLoadSuccessful = true

    @State private var showProductiveImportAlert = false
    @State private var productiveDataExists = false

    @State private var syncCoordinator: SyncCoordinator?

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            contentView
                .environmentObject(patientStore)
                .environmentObject(navigationStore)
                .environmentObject(deviceConfigStore)
                .environmentObject(syncStateStore)
                .modifier(SyncEnvironmentModifier(syncCoordinator: syncCoordinator))
                .task {
                    await performInitialSetup()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task { await syncCoordinator?.connectivityMonitor.checkConnectivity() }
                    case .background:
                        syncCoordinator?.pushOnBackground()
                    default:
                        break
                    }
                }
                .alert(isPresented: $showProductiveImportAlert) {
                    Alert(
                        title: Text("Produktiv-Daten gefunden"),
                        message: Text("Möchtest Du die Daten importieren?"),
                        primaryButton: .destructive(Text("Importieren")) {
                            importProductiveData()
                        },
                        secondaryButton: .cancel()
                    )
                }
        }
    }

    /// Helper to inject optional SyncCoordinator into the environment.
    private struct SyncEnvironmentModifier: ViewModifier {
        let syncCoordinator: SyncCoordinator?

        func body(content: Content) -> some View {
            if let coordinator = syncCoordinator {
                content.environmentObject(coordinator)
            } else {
                content
            }
        }
    }

    /// The main content view, which switches between the app content, an error message, or a loading indicator.
    @ViewBuilder
    private var contentView: some View {
        if isSetupComplete {
            ContentView()
                .environmentObject(patientStore)
        } else if !isLoadSuccessful {
            Text(
                NSLocalizedString(
                    "errorLoadFailed",
                    comment: "Loading failed. Please restart the app."
                )
            )
            .foregroundColor(.error)
            .multilineTextAlignment(.center)
            .padding()
        } else {
            ProgressView(
                NSLocalizedString(
                    "initializingApp",
                    comment: "Initializing app…"
                )
            )
            .progressViewStyle(.circular)
            .padding()
        }
    }

    // MARK: - App Initialization

    /// Indicates whether parameter data should be copied on first launch.
    @MainActor
    let shouldCopy = true

    /// Performs initial app setup: creates directories, loads data, and requests camera permission.
    private func performInitialSetup() async {
        if checkForProductiveData() {
            showProductiveImportAlert = true
        }

        guard setupAppDirectories(shouldCopyParameterData: shouldCopy) else {
            isLoadSuccessful = false
            return
        }

        // Migrate legacy Int therapist IDs to UUIDs (one-time, idempotent)
        TherapistIdMigrator.runIfNeeded()

        guard loadAppData() else {
            isLoadSuccessful = false
            showErrorAlert(
                errorMessage: NSLocalizedString(
                    "errorLoadDataFailed",
                    comment: "The app could not load required data."
                )
            )
            return
        }

        // ✅ 1) Patienten deterministisch laden (unabhängig davon, ob PatientStore im init schon geladen hat)
        await patientStore.loadAllPatients()

        // ✅ 2) Überprüfung der Serialnummber aller Sessions:
        CalendarIndexBackfiller.runAtAppStart(
            patients: patientStore.patients,
            patientStore: patientStore
        )

        await requestCameraPermissionIfNeeded()

        // Initialize sync system
        initializeSyncCoordinator()

        isLoadSuccessful = true
        isSetupComplete = true
    }

    // MARK: - Camera Permission

    /// Requests camera permission from the user if not already granted.
    private func requestCameraPermissionIfNeeded() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                showErrorAlert(
                    errorMessage: NSLocalizedString(
                        "cameraAccessDenied",
                        comment: "Camera access was denied."
                    )
                )
            }
        case .denied, .restricted:
            showErrorAlert(
                errorMessage: NSLocalizedString(
                    "cameraAccessRestricted",
                    comment: "Camera access already denied or restricted."
                )
            )
        @unknown default:
            break
        }
    }

    // MARK: - Sync Initialization

    /// Creates and starts the sync coordinator if the device is configured.
    @MainActor
    private func initializeSyncCoordinator() {
        let client = NexusSyncClient(deviceConfigStore: deviceConfigStore)
        let monitor = ConnectivityMonitor(client: client)

        let coordinator = SyncCoordinator(
            patientStore: patientStore,
            outboundQueue: outboundQueue,
            versionTracker: versionTracker,
            syncStateStore: syncStateStore,
            deviceConfigStore: deviceConfigStore,
            client: client,
            connectivityMonitor: monitor
        )

        syncCoordinator = coordinator

        // Wire availability store if a therapist is selected
        if let therapistId = AppGlobals.shared.therapistId {
            let store = AvailabilityStore(
                therapistId: therapistId.uuidString,
                baseDirectory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            )
            coordinator.wireAvailabilityStore(store)
        }

        // Start auto-sync if device has a server URL configured
        if !deviceConfigStore.config.serverURL.isEmpty {
            coordinator.startAutoSync()
        }
    }

    // MARK: - Data Loading

    /// Loads all required app parameters and templates.
    private func loadAppData() -> Bool {
        return loadAppParameters()
    }

    // MARK: - Import productive Data

    private func checkForProductiveData() -> Bool {
        guard let resourcePath = Bundle.main.resourcePath else { return false }
        let zipURL = URL(fileURLWithPath: resourcePath).appendingPathComponent(
            "Documents.zip"
        )
        productiveDataExists = FileManager.default.fileExists(
            atPath: zipURL.path
        )
        return productiveDataExists
    }

    private func importProductiveData() {
        guard
            let zipURL = Bundle.main.url(
                forResource: "Documents",
                withExtension: "zip"
            )
        else {
            return
        }

        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let container = docs.deletingLastPathComponent()

        do {
            let contents = try fm.contentsOfDirectory(atPath: docs.path)
            for item in contents {
                try fm.removeItem(at: docs.appendingPathComponent(item))
            }

            let ok = SSZipArchive.unzipFile(
                atPath: zipURL.path,
                toDestination: container.path
            )
            if ok {
                Task { await performInitialSetup() }
            } else {
                showErrorAlert(
                    errorMessage: "ZIP konnte nicht entpackt werden."
                )
            }
        } catch {
            showErrorAlert(errorMessage: "Import-Fehler: \(error)")
        }
    }
}
