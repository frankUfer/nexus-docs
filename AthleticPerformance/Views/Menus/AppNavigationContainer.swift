import SwiftUI

struct AppNavigationContainer: View {
    @State private var selectedPatientIDs: Set<UUID> = []
    @State private var selectedBillingOption: BillingOption? = nil
    @State private var selectedSettingsOption: SettingsOption? = nil
    @State private var selectedSyncOption: SyncOption? = nil          // ← NEW
    @State private var selectedPatientTab: PatientDetailTab = .masterData
    @State private var selectedTherapy: Therapy? = nil
    @EnvironmentObject var patientStore: PatientStore
    //@StateObject private var patientStore = PatientStore()
    @State private var patientListRefreshID = UUID()
    @State private var calendarCurrentDate = Date()
    @State private var calendarViewType: CalendarViewType = .day
    @State private var showCalendar = false
    @State private var didEnsureCalendar = false
    @AppStorage("showAllDaySessions") private var showAllDaySessions = true
    @EnvironmentObject var navigationStore: AppNavigationStore
    
    var body: some View {
        NavigationSplitView {
            mainMenuSidebar()
        } content: {
            contextSidebar()
        } detail: {
            detailView()
        }
        .id(navigationStore.selectedMainMenu)
        .onAppear {
            if !didEnsureCalendar {
                LocalCalendarManager.ensureCalendarExists()
                didEnsureCalendar = true
            }
        }
        .onChange(of: navigationStore.selectedMainMenu) { _, newValue in
            if newValue != .appointments {
                showCalendar = false
            }
        }
        .onChange(of: navigationStore.selectedPatientID) { _, _ in
            if navigationStore.selectedMainMenu == .patients {
                showCalendar = false
            }
        }
        // ⬇️ Hier einfügen: Auswahl aufräumen, falls Patient gelöscht wurde
        .onChange(of: patientStore.patients) { _, _ in
            if let id = navigationStore.selectedPatientID,
               !patientStore.patients.contains(where: { $0.id == id }) {
                navigationStore.selectedPatientID = nil
                selectedTherapy = nil
                selectedPatientTab = .masterData
            }
        }
    }

    // MARK: - Sidebar 1: Hauptmenü
    @ViewBuilder
    private func mainMenuSidebar() -> some View {
        List(selection: $navigationStore.selectedMainMenu) {
            Section {
                HStack {
                    Spacer()
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                        .accessibilityHidden(true)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section {
                ForEach(MainMenu.allCases) { menu in
                    Label(menu.label, systemImage: menu.icon)
                        .tag(menu)
                }
                .foregroundColor(.secondary)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Sidebar 2: Kontextabhängige Liste
    @ViewBuilder
    private func contextSidebar() -> some View {
        switch navigationStore.selectedMainMenu {
        case .patients:
            PatientListView(
                refreshTrigger: $patientListRefreshID,
                patientStore: patientStore,
                showContextMenu: true,
                onSelectPatient: { selectedPatient in
                    navigationStore.selectedPatientID = selectedPatient.id
                }
            )
        case .appointments:
            MultiPatientListView(
                selectedPatientIDs: $selectedPatientIDs,
                refreshTrigger: $patientListRefreshID,
                patientStore: patientStore,
                showContextMenu: false,
                onSelectPatient: { selectedPatient in
                    // optional: zusätzliche Logik, z. B. Logging oder Navigation
                },
                currentDate: $calendarCurrentDate,
                selectedView: $calendarViewType,
                showCalendar: $showCalendar
            )
        case .billing:
            BillingMenuView(selectedBillingOption: $selectedBillingOption)

        // ── NEW: Sync menu with Backup / Restore options ──
        case .sync:
            SyncMenuView(selectedSyncOption: $selectedSyncOption)

        case .settings:
            SettingsMenuView(selectedSettingsOption: $selectedSettingsOption)
        case .none:
            Text("")
        }
    }

    // MARK: - Detailansicht mit Toolbar-Button oben rechts
    @ViewBuilder
    private func detailView() -> some View {
        VStack(spacing: 0) {
            contentForSelectedMenu()
        }
    }

    // MARK: - Gemeinsame Detailinhalte für beide Modi
    @ViewBuilder
    private func contentForSelectedMenu() -> some View {
        switch navigationStore.selectedMainMenu {
        case .patients:
            if let selectedID = navigationStore.selectedPatientID,
                   let pBinding = patientStore.bindingForPatient(id: selectedID) {
                    PatientDetailContainerView(
                        patient: pBinding,
                        selectedTab: $selectedPatientTab,
                        selectedTherapy: $selectedTherapy,
                        refreshTrigger: $patientListRefreshID
                    )
                    .environmentObject(patientStore)
                } else {
                    ContentUnavailableView(
                        "",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(NSLocalizedString("selectPatientHint", comment: "Please select a patient from the list."))
                    )
                }

        case .appointments:
            if navigationStore.selectedMainMenu == .appointments {
                HStack(spacing: 0) {
                    MultiPatientCalendarView(
                        patients: patientStore.patients,
                        selectedPatientIds: selectedPatientIDs,
                        currentDate: $calendarCurrentDate,
                        selectedView: $calendarViewType
                    )
                }
            }
                    
        case .billing:
            switch selectedBillingOption {
            case .invoicing:
                BillingMainView()
                    .environmentObject(patientStore)
            case .claimsManagement:
                ClaimsMainView()
            case .none:
                ContentUnavailableView(
                    "",
                    systemImage: "gearshape",
                    description: Text(NSLocalizedString("noSelection", comment: "Please make a selection"))
                )
            }

        // ── NEW: Sync detail views ──
        case .sync:
            switch selectedSyncOption {
            case .status:
                SyncStatusView()
            case .sync:
                SyncNowView()
            case .settings:
                SyncSettingsView()
            case .none:
                ContentUnavailableView(
                    "",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text(NSLocalizedString("syncSelectOption",
                        comment: "Please select a sync option"))
                )
            }
            
        case .settings:
            switch selectedSettingsOption {
            case .practiceInfo:
                PracticeInfoView()
            case .insurances:
                InsuranceView()
            case .specialties:
                SpecialtyView()
            case .availability:
                AvailabilityEditorView()
            case .none:
                ContentUnavailableView(
                    "",
                    systemImage: "gearshape",
                    description: Text(NSLocalizedString("noSelection", comment: "Please make a selection"))
                )
            }

        default:
            ContentUnavailableView(
                "",
                systemImage: "gearshape",
                description: Text(NSLocalizedString("noSelection", comment: "Please make a selection"))
            )
        }
    }
        
    private var sessionsForSelectedPatients: [TreatmentSessions] {
        let relevantPatients: [Patient]

        if selectedPatientIDs.isEmpty {
            relevantPatients = patientStore.patients
        } else {
            relevantPatients = patientStore.patients.filter { selectedPatientIDs.contains($0.id) }
        }

        let result = relevantPatients
            .flatMap { $0.therapies.compactMap { $0 } }
            .flatMap { $0.therapyPlans }
            .flatMap { $0.treatmentSessions }

        return result
    }
        
    private var patientsForSelected: [UUID: Patient] {
        Dictionary(
            uniqueKeysWithValues:
                patientStore.patients
                    .filter { selectedPatientIDs.contains($0.id) }
                    .map { ($0.id, $0) }
        )
    }
    
    private var patientsById: [UUID: Patient] {
        Dictionary(
            uniqueKeysWithValues:
                patientStore.patients.map { ($0.id, $0) }
        )
    }
}

