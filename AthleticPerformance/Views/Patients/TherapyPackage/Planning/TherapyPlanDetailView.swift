//
//  TherapyPlanDetailView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.05.25.
//

import MessageUI
import SwiftUI

@MainActor
struct TherapyPlanDetailView: View {
    @Binding var plan: TherapyPlan
    let diagnoses: [Diagnosis]
    let allServices: [TreatmentService]
    let availableTherapists: [Therapists]
    let patient: Patient
    let therapy: Therapy
    @EnvironmentObject var patientStore: PatientStore

    var onUpdatePlan: ((TherapyPlan) -> Void)? = nil

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedSession: TreatmentSessions? = nil
    @State private var planSnapshot: String = ""
    @State private var travelTimeRequest: TravelTimeRequest? = nil
    @State private var therapistAvailability: [AvailabilitySlot] = []
    @State private var sessionAllowsEditing = false
    @State private var therapyPlanAllowsPlanning = true
    @State private var therapyPlanAllowsSendingAppointments = false
    @State private var therapyPlanAllowsSendingPlannedAppointments = false
    @State private var therapyPlanAllowsCancelingAppointments = false
    @State private var sessionsMarkedForCancellation: Set<UUID> = []

    @State private var toastMessage = ""
    @State private var showToast = false

    @State private var ownSessions: [TreatmentSessions] = []
    @State private var otherSessions: [TreatmentSessions] = []

    private var availableAddresses: [LabeledValue<Address>] {
        patient.addresses
    }
    
    @State private var showAddRemedySheet = false

    struct TravelTimeRequest: Identifiable {
        let id = UUID()
        let origin: Address
        let destination: Address
        let estimated: Int
        let continuation: CheckedContinuation<Int?, Never>
    }

    struct TravelTimeSheetValidator: TravelTimeValidator {
        @Binding var binding: TherapyPlanDetailView.TravelTimeRequest?

        func confirmTravelTime(
            estimatedMinutes: Int,
            origin: Address,
            destination: Address
        ) async -> Int? {
            await withCheckedContinuation { continuation in
                binding = TherapyPlanDetailView.TravelTimeRequest(
                    origin: origin,
                    destination: destination,
                    estimated: estimatedMinutes,
                    continuation: continuation
                )
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        if sessionAllowsEditing {
                            editablePlanSection
                        } else {
                            readonlyPlanSection
                        }
                    }

                    if !plan.treatmentSessions.isEmpty {
                        sessionListSection
                    }
                }
                .padding()
            }
            .onAppear(perform: onAppearSetup)
            .sheet(
                item: Binding(
                    get: {
                        // Nur anzeigen, wenn eine Session ausgewählt ist UND sie bearbeitbar ist
                        if let s = selectedSession, s.draft || s.isPlanned {
                            return s
                        } else {
                            return nil
                        }
                    },
                    set: { selectedSession = $0 }
                ),
                content: editSessionSheet
            )
            .sheet(item: $travelTimeRequest, content: travelTimeSheet)
            .onChange(of: computedPlanSnapshot) { _, newValue in
                guard newValue != planSnapshot else { return }
                DispatchQueue.main.async {
                    onSnapshotChanged(newValue)
                }
            }
        }
    }

    @ViewBuilder
    private var editablePlanSection: some View {
        showGeneralInformation
        if therapyPlanAllowsPlanning {
            treatmentServiceList
            generateSessionsButtons
        } else {
            showTreatmentServiceList
        }
    }
    
    private var showGeneralInformation: some View {
        DisplaySectionBox(
            title: NSLocalizedString(
                "generalInfo",
                comment: "General information"
            ),
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            titleAndTherapist
            diagnosisInfo
            if therapyPlanAllowsPlanning {
                startDatePicker
                patientAddressPicker
                numberOfSessionsPicker
                frequencyPicker
                if plan.frequency == .multiplePerWeek {
                    weekdaysPicker
                }
                timeOfDayPicker
            } else {
                showPeriod
                showPatientAddress
                numberOfSessionsPicker
            }
        }
    }

    @ViewBuilder
    private var readonlyPlanSection: some View {
        showTitleAndTherapist
        showDiagnosisInfo
        showPeriod
        showPatientAddress
        showNumberOfSessions
        showTreatmentServiceList
    }

    private var sessionActionButtons: some View {
        HStack {
            if therapyPlanAllowsCancelingAppointments {
                Button {
                    cancelIcsAppointments(
                        for: plan.treatmentSessions.filter { $0.isScheduled }
                    )
                } label: {
                    Image(systemName: "calendar.badge.minus")
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            if !sessionsMarkedForCancellation.isEmpty {
                Spacer().frame(width: 24)
                Button {
                    cancelIcsAppointments(
                        for: plan.treatmentSessions.filter {
                            sessionsMarkedForCancellation.contains($0.id)
                        }
                    )
                    sessionsMarkedForCancellation.removeAll()
                } label: {
                    Image(systemName: "calendar.badge.minus")
                        .padding(12)
                        .foregroundColor(.positiveCheck)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            Spacer()

            if therapyPlanAllowsSendingPlannedAppointments {
                Button {
                    sendIcsAppointments(
                        for: plan.treatmentSessions.filter { $0.isPlanned }
                    )
                } label: {
                    Image(systemName: "paperplane")
                        .padding(12)
                        .foregroundColor(.error)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }

                Spacer().frame(width: 24)
            }

            if therapyPlanAllowsSendingAppointments {
                Button {
                    sendIcsAppointments(
                        for: plan.treatmentSessions.filter {
                            $0.draft || $0.isPlanned
                        }
                    )
                } label: {
                    Image(systemName: "paperplane")
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private var generateSessionsButtons: some View {
        HStack {
    
            Spacer()

            if therapyPlanAllowsPlanning {
                Button {
                    Task {
                        await generateSessionDrafts()
                    }
                } label: {
                    Label(
                        NSLocalizedString(
                            "createUpdateSessions",
                            comment: "Create or update sessions"
                        ),
                        systemImage: "calendar.badge.plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .alert(
                    NSLocalizedString("error", comment: "Error"),
                    isPresented: $showError
                ) {
                    Button(NSLocalizedString("ok", comment: "Ok"), role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }

            Spacer()

        }
       
    }

    @MainActor
    private func generateSessionDrafts() async {
        guard let therapistId = plan.therapistId else { return }

        if therapistAvailability.isEmpty {
            errorMessage = NSLocalizedString(
                "noAvailabilityForTherapist",
                comment: ""
            )
            showError = true
            return
        }
        
        if let gap = checkTherapistAvailabilityHorizon(
            startDate: plan.startDate ?? Date(),
            numberOfSessions: plan.numberOfSessions,
            availability: therapistAvailability
        ) {
            errorMessage = NSLocalizedString("noAvailabilityForTherapistForPeriod",comment: "") + " \(gap.missingFrom) - \(gap.missingUntil)"
            showError = true
            return
        }

        if plan.treatmentServiceIds.isEmpty {
            errorMessage = NSLocalizedString("noRemediesSelected", comment: "")
            showError = true
            return
        }

        if plan.frequency == .multiplePerWeek
            && (plan.weekdays?.isEmpty ?? true)
        {
            errorMessage = NSLocalizedString("noWeekdaysSelected", comment: "")
            showError = true
            return
        }

        guard
            let selectedAddress = availableAddresses.first(where: {
                $0.id == plan.addressId
            })?.value
        else {
            errorMessage = NSLocalizedString("noPatientAddress", comment: "")
            showError = true
            return
        }

        updateAllOtherSessions(for: patient)

        let fixed = plan.treatmentSessions.filter {
            !$0.draft
        }
        
        let (newDrafts, usedRelaxed) = await generateTreatmentProposals(
            plan: plan,
            services: allServices,
            patientAddress: selectedAddress,
            therapistId: therapistId,
            therapistAvailability: therapistAvailability,
            ownSessions: ownSessions,
            otherSessions: otherSessions.filter { !$0.draft },
            validator: self,
            totalCount: plan.numberOfSessions,
            patientId: therapy.patientId
        )

        plan.treatmentSessions = fixed + newDrafts
        onUpdatePlan?(plan)
        updateSessionEditability(for: plan)
        
        if usedRelaxed {
            showErrorAlert(
                errorMessage:"Wunschzeit oder Frequenz konnte nicht vollständig eingehalten werden. Termine wurden nach frühestmöglicher Verfügbarkeit geplant."
                )
        }
    }

    private var sessionListSection: some View {
        DisplaySectionBox(
            title: NSLocalizedString(
                "plannedSessions",
                comment: "Planned sessions"
            ),
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(alignment: .leading, spacing: 8) {
                sessionActionButtons
                ForEach(
                    Array(
                        plan.treatmentSessions.sorted(by: {
                            $0.startTime < $1.startTime
                        }).enumerated()
                    ),
                    id: \.element.id
                ) { index, session in
                    sessionRow(
                        for: session,
                        isLast: index == plan.treatmentSessions.count - 1
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(for session: TreatmentSessions, isLast: Bool)
        -> some View
    {
        let isInteractive =
            session.draft || session.isPlanned || session.isScheduled
        let baseView = SessionWithOptionalDivider(
            session: session,
            isLast: isLast,
            allServices: allServices,
            availableTherapists: availableTherapists,
            isMarkedForCancellation: sessionsMarkedForCancellation.contains(
                session.id
            ),
            onToggleCancellation: {
                if sessionsMarkedForCancellation.contains(session.id) {
                    sessionsMarkedForCancellation.remove(session.id)
                } else {
                    sessionsMarkedForCancellation.insert(session.id)
                }
            }
        )

        if isInteractive {
            baseView
                .overlay(overlayButtons(for: session))
                .onTapGesture { selectedSession = session }
        } else {
            baseView
        }
    }

    private func overlayButtons(for session: TreatmentSessions) -> some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Spacer()
                    if session.draft || session.isPlanned {
                        Button {
                            sendIcsAppointments(for: [session])
                        } label: {
                            Image(systemName: "paperplane")
                                .padding(12)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    if session.isScheduled
                        && !sessionsMarkedForCancellation.contains(session.id)
                    {
                        Button {
                            cancelIcsAppointments(for: [session])
                        } label: {
                            Image(systemName: "calendar.badge.minus")
                                .padding(12)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func onAppearSetup() {
        updateAllOtherSessions(for: patient)
        updateSessionEditability(for: plan)

        if plan.addressId == nil, let firstId = availableAddresses.first?.id {
            plan.addressId = firstId
        }
        if let therapistId = plan.therapistId {
            let store = AvailabilityStore(
                therapistId: therapistId.uuidString,
                baseDirectory: FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                )[0]
            )
            therapistAvailability = store.slots
        }
    }

    private func onSnapshotChanged(_ newValue: String) {
        updateSessionEditability(for: plan)
        savePlan()
        planSnapshot = newValue
    }

    private func editSessionSheet(session: TreatmentSessions) -> some View {
        if let index = plan.treatmentSessions.firstIndex(where: {
            $0.id == session.id
        }) {
            return AnyView(
                NavigationStack {
                    EditTreatmentSessionView(
                        session: plan.treatmentSessions[index],
                        patient: patient,
                        allServices: allServices,
                        availableTherapists: availableTherapists,
                        availableAddresses: patient.addresses.map { $0.value },
                        allOtherSessions: ownSessions + otherSessions,
                        availability: therapistAvailability,
                        validator: TravelTimeSheetValidator(
                            binding: $travelTimeRequest
                        ),
                        onCommit: { updated in
                            plan.treatmentSessions[index] = updated
                            updateSessionEditability(for: plan)
                            savePlan()
                        }
                    )
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    private func travelTimeSheet(request: TravelTimeRequest) -> some View {
        FixedHeightSheet(height: 250, id: request.id) {
            TravelTimeConfirmationSheet(
                estimatedMinutes: request.estimated,
                origin: request.origin,
                destination: request.destination,
                onConfirm: { confirmed in
                    request.continuation.resume(returning: confirmed)
                    travelTimeRequest = nil
                },
                onCancel: {
                    request.continuation.resume(returning: nil)
                    travelTimeRequest = nil
                }
            )
        }
    }

    /// Therapy plan title and therapist
    private var titleAndTherapist: some View {
        HStack {
            TextField(
                "Plan Title",
                text: Binding(
                    get: { plan.title ?? "" },
                    set: { plan.title = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)

            Spacer()

            Picker(
                "Therapist",
                selection: Binding(
                    get: {
                        plan.therapistId ?? availableTherapists.first?.id ?? UUID()
                    },
                    set: { plan.therapistId = $0 }
                )
            ) {
                ForEach(availableTherapists, id: \.id) { therapist in
                    Text(therapist.fullName).tag(therapist.id)
                }
            }
            .tint(Color.secondary)
        }
    }

    private var diagnosisInfo: some View {
        // Wenn keine Diagnosen vorhanden sind und auch keine zugewiesen ist → zeige nichts
        guard !diagnoses.isEmpty || plan.diagnosisId != nil else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(
                        "\(NSLocalizedString("diagnosis", comment: "Diagnosis")):"
                    )
                    .font(.headline)

                    if diagnoses.isEmpty, let diagnosisId = plan.diagnosisId {
                        if let found = therapy.diagnoses.first(where: {
                            $0.id == diagnosisId
                        }) {
                            Text(formatDiagnosisTitle(found))
                                .foregroundColor(.secondary)
                        } else {
                            Text(
                                NSLocalizedString(
                                    "unknownDiagnosis",
                                    comment: "Unknown diagnosis"
                                )
                            )
                            .foregroundColor(.secondary)
                        }
                    } else if diagnoses.count == 1,
                        let diagnosis = diagnoses.first
                    {
                        Text(formatDiagnosisTitle(diagnosis))
                            .foregroundColor(.secondary)
                    } else {
                        Picker(
                            "Select Diagnosis",
                            selection: Binding(
                                get: {
                                    plan.diagnosisId ?? diagnoses.first?.id
                                        ?? UUID()
                                },
                                set: { plan.diagnosisId = $0 }
                            )
                        ) {
                            ForEach(diagnoses, id: \.id) { diagnosis in
                                Text(formatDiagnosisTitle(diagnosis))
                                    .tag(diagnosis.id)
                            }
                        }
                        .tint(.secondary)
                    }
                }
            }
        )
    }

    private var startDatePicker: some View {
        DatePicker(
            NSLocalizedString("startDate", comment: "Start date"),
            selection: Binding(
                get: { plan.startDate ?? Date() },
                set: { plan.startDate = $0 }
            ),
            displayedComponents: .date
        )
    }

    private var frequencyPicker: some View {
        Picker(
            NSLocalizedString("frequency", comment: "Frequency"),
            selection: Binding(
                get: { plan.frequency ?? .weekly },
                set: { plan.frequency = $0 }
            )
        ) {
            ForEach(TherapyFrequency.allCases) { freq in
                Text(freq.localizedName).tag(freq)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .pickerStyle(.segmented)
    }

    /// Favourit weekday selection - multiple selections possible. Will only apear on multiple sessions a week
    private var weekdaysPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Weekday.allCases) { day in
                    Button(action: {
                        if (plan.weekdays ?? []).contains(day) {
                            plan.weekdays?.removeAll { $0 == day }
                        } else {
                            if plan.weekdays == nil { plan.weekdays = [] }
                            plan.weekdays?.append(day)
                        }
                    }) {
                        Text(day.localizedName)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                (plan.weekdays ?? []).contains(day)
                                    ? Color.accentColor
                                    : Color.gray.opacity(0.2)
                            )
                            .foregroundColor(
                                (plan.weekdays ?? []).contains(day)
                                    ? .white : .primary
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    /// Favourit time of the day selection
    private var timeOfDayPicker: some View {
        Picker(
            NSLocalizedString("timeOfDay", comment: "Time of day"),
            selection: Binding(
                get: { plan.preferredTimeOfDay ?? .morning },
                set: { plan.preferredTimeOfDay = $0 }
            )
        ) {
            ForEach(TimeOfDay.allCases, id: \.self) { time in
                Text(time.localizedName).tag(time)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .pickerStyle(.segmented)
    }

    /// Patient address to be used for session planning
    private var patientAddressPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(
                    "\(NSLocalizedString("patientAddress", comment: "Patient address")):"
                )
                .font(.headline)

                if availableAddresses.count == 1,
                    let address = availableAddresses.first
                {
                    // Nur eine Adresse vorhanden – zeige Label + Adresse an
                    Text(
                        "\(NSLocalizedString(address.label, comment: "Label")) - \(address.value.street), \(address.value.postalCode) \(address.value.city)"
                    )
                    .foregroundColor(.secondary)
                } else {
                    Picker(
                        "Select Address",
                        selection: Binding(
                            get: {
                                plan.addressId ?? availableAddresses.first?.id
                                    ?? UUID()
                            },
                            set: { plan.addressId = $0 }
                        )
                    ) {
                        ForEach(availableAddresses, id: \.id) { address in
                            Text(
                                "\(NSLocalizedString(address.label, comment: "Label")) - \(address.value.street), \(address.value.postalCode) \(address.value.city)"
                            )
                            .tag(address.id)
                        }
                    }
                    .tint(Color.secondary)
                }
            }
        }
    }
    
    private var numberOfSessionsPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("numberOfSessions", comment: "Number of sessions") + ":")
                    .font(.headline)

                Spacer()

                let minSessions = max(1, plan.treatmentSessions.filter { !$0.draft }.count)
                
                Slider(
                    value: Binding(
                        get: { Double(plan.numberOfSessions) },
                        set: { plan.numberOfSessions = Int($0) }
                    ),
                    in: Double(minSessions)...20,
                    step: 1
                )
                .frame(maxWidth: 200)

                Text("\(plan.numberOfSessions)")
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
    
    /// Auswahl / Verwaltung der Remedies (Heilmittel / TreatmentServices)
    private var treatmentServiceList: some View {
        
        let selectedServices = allServices
            .filter { plan.treatmentServiceIds.contains($0.internalId) }
            .sorted { a, b in
                a.de.localizedCaseInsensitiveCompare(b.de) == .orderedAscending
            }
        
        let remainingServices = allServices
            .filter { !plan.treatmentServiceIds.contains($0.internalId) }
            .sorted { a, b in
                a.de.localizedCaseInsensitiveCompare(b.de) == .orderedAscending
            }
        
        // Alle Service-IDs, die irgendwo in Sessions dieses Plans tatsächlich verwendet werden
        let usedServiceIdsInSessions: Set<UUID> = Set(
            plan.treatmentSessions.flatMap { $0.treatmentServiceIds }
        )
        
        return DisplaySectionBox(
            title: NSLocalizedString(
                "remedies",
                comment: "Remedies"
            ),
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(alignment: .leading, spacing: 8) {
                
                // Header mit Add-Button
                HStack(alignment: .firstTextBaseline) {
                    
                    Spacer()
                    
                    Button {
                        showAddRemedySheet = true
                    } label: {
                        
                        Label(
                            NSLocalizedString(
                                "addRemedy",
                                comment: "Add remedy"
                            ),
                            systemImage: "plus.circle.fill"
                        )
                        .foregroundColor(.addButton)
                    }
                    .disabled(remainingServices.isEmpty)
                    .opacity(remainingServices.isEmpty ? 0.4 : 1.0)
                    .sheet(isPresented: $showAddRemedySheet) {
                        NavigationView {
                            List {
                                if remainingServices.isEmpty {
                                    Text(
                                        NSLocalizedString(
                                            "allRemediesAlreadySelected",
                                            comment: "All remedies already selected"
                                        )
                                    )
                                    .foregroundColor(.secondary)
                                } else {
                                    ForEach(remainingServices, id: \.internalId) { service in
                                        Button {
                                            addService(service)
                                            showAddRemedySheet = false
                                        } label: {
                                            HStack {
                                                Text(serviceDisplayString(for: service))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                            .navigationTitle(
                                NSLocalizedString(
                                    "selectRemedy",
                                    comment: "Select Remedy"
                                )
                            )
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(
                                        NSLocalizedString("cancel", comment: "Cancel")
                                    ) {
                                        showAddRemedySheet = false
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Inhalt: ausgewählte Remedies
                if selectedServices.isEmpty {
                    Text(
                        NSLocalizedString(
                            "noRemediesSelected",
                            comment: "No remedies selected"
                        )
                    )
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                } else {
                    ForEach(selectedServices, id: \.internalId) { service in
                        
                        // ist dieses Remedy schon in irgendeiner Session drin?
                        let isUsedInPlanSessions =
                        usedServiceIdsInSessions.contains(service.internalId)
                        
                        VStack(spacing: 4) {
                            HStack(alignment: .center, spacing: 12) {
                                
                                Text(serviceDisplayString(for: service))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Löschbutton NUR wenn nicht benutzt
                                if !isUsedInPlanSessions {
                                    Button(role: .destructive) {
                                        removeService(service)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .padding(8)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            
                            Divider()
                                .background(Color.divider.opacity(0.5))
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var showTitleAndTherapist: some View {
        HStack {
            Text("\(NSLocalizedString("title", comment: "Title")):")
                .font(.headline)
            Text(
                plan.title?.isEmpty == false
                    ? plan.title!
                    : NSLocalizedString(
                        "untitledPlan",
                        comment: "Untitled plan"
                    )
            )
            .font(.body)
            .foregroundColor(.secondary)

            Spacer()

            Text("\(NSLocalizedString("therapist", comment: "Therapist")):")
                .font(.headline)
            if let therapist = availableTherapists.first(where: {
                $0.id == plan.therapistId
            }) {
                Text(therapist.fullName)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Text("-")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

        }
    }

    private var showDiagnosisInfo: some View {
        guard !diagnoses.isEmpty || plan.diagnosisId != nil else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(
                        "\(NSLocalizedString("diagnosis", comment: "Diagnosis")):"
                    )
                    .font(.headline)

                    if let diagnosisId = plan.diagnosisId {
                        if let found = therapy.diagnoses.first(where: {
                            $0.id == diagnosisId
                        }) {
                            Text(formatDiagnosisTitle(found))
                                .foregroundColor(.secondary)
                        } else {
                            Text(
                                NSLocalizedString(
                                    "unknownDiagnosis",
                                    comment: "Unknown diagnosis"
                                )
                            )
                            .foregroundColor(.secondary)
                        }
                    } else if diagnoses.count == 1,
                        let diagnosis = diagnoses.first
                    {
                        Text(formatDiagnosisTitle(diagnosis))
                            .foregroundColor(.secondary)
                    } else {
                        Text("-")
                            .foregroundColor(.secondary)
                    }
                }
            }
        )
    }

    private var showPeriod: some View {
        HStack {
            Text("\(NSLocalizedString("period", comment: "Period")):")
                .font(.headline)

            let dates = plan.treatmentSessions.map(\.date)
            if let start = dates.min(), let end = dates.max() {
                Text("\(formattedDate(start)) – \(formattedDate(end))")
                    .foregroundColor(.secondary)
            } else if let fallback = plan.startDate {
                Text(formattedDate(fallback))
                    .foregroundColor(.secondary)
            } else {
                Text("–")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var showPatientAddress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(
                    "\(NSLocalizedString("patientAddress", comment: "Patient address")):"
                )
                .font(.headline)

                let address = availableAddresses.first(where: {
                    $0.id == plan.addressId
                })

                if let address = address {
                    Text(
                        "\(NSLocalizedString(address.label, comment: "Label")) – \(address.value.street), \(address.value.postalCode) \(address.value.city)"
                    )
                    .foregroundColor(.secondary)
                } else {
                    Text(
                        NSLocalizedString(
                            "noAddressSelected",
                            comment: "No address selected"
                        )
                    )
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private var showNumberOfSessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(
                    "\(NSLocalizedString("numberOfSessions", comment: "Number of sessions")):"
                )
                .font(.headline)

                Text("\(plan.numberOfSessions)")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var showTreatmentServiceList: some View {
        DisplaySectionBox(
            title: NSLocalizedString(
                "remedies",
                comment: "Remedies"
            ),
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            // Alle in Sessions genutzten Service-IDs (einmalig)
            let usedServiceIds = Set(
                plan.treatmentSessions.flatMap { $0.treatmentServiceIds }
            )
            
            // Gefilterte Service-Objekte aus globaler Liste
            let usedServices = allServices.filter {
                usedServiceIds.contains($0.internalId)
            }
        
            VStack(spacing: 4) {
                
                ForEach(usedServices, id: \.internalId) { service in
                    HStack (alignment: .center, spacing: 12) {
                        Text(
                            "\(service.de) (\(service.quantity ?? 0) \(service.unit ?? ""))"
                        )
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                        .background(Color.divider.opacity(0.5))
                }
                .padding(.top, 4)
            }
        }
    }

    private var computedPlanSnapshot: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(plan) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func savePlan() {
        // Lokale Kopien, damit SwiftUI-Bindings nicht durcheinanderkommen
        let currentPlan = plan
        var updatedPatient = patient
        var updatedTherapy = therapy

        // Therapieplan aktualisieren oder hinzufügen
        if let planIndex = updatedTherapy.therapyPlans.firstIndex(where: {
            $0.id == currentPlan.id
        }) {
            updatedTherapy.therapyPlans[planIndex] = currentPlan
        } else {
            updatedTherapy.therapyPlans.append(currentPlan)
        }

        // Patient mit aktualisierter Therapie zurückschreiben
        if let therapyIndex = updatedPatient.therapies.firstIndex(where: {
            $0?.id == updatedTherapy.id
        }) {
            updatedPatient.therapies[therapyIndex] = updatedTherapy
        } else {
            updatedPatient.therapies.append(updatedTherapy)
        }

        patientStore.updatePatient(updatedPatient, waitUntilSaved: false)
    }

    private func formatDiagnosisTitle(_ diagnosis: Diagnosis) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale.current
        return "\(diagnosis.title) – \(formatter.string(from: diagnosis.date))"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private struct SessionWithOptionalDivider: View {
        let session: TreatmentSessions
        let isLast: Bool
        let allServices: [TreatmentService]
        let availableTherapists: [Therapists]

        let isMarkedForCancellation: Bool
        let onToggleCancellation: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                TreatmentSessionRow(
                    session: session,
                    allServices: allServices,
                    therapists: availableTherapists,
                    isMarkedForCancellation: isMarkedForCancellation,
                    showCancellation: true,
                    onToggleCancellation: onToggleCancellation
                )
                .buttonStyle(.plain)

            }
        }
    }

    private func updateSessionEditability(for plan: TherapyPlan) {
        therapyPlanAllowsPlanning = plan.treatmentSessions.isEmpty || plan.treatmentSessions.contains(where: {$0.draft}) || plan.treatmentSessions.count < plan.numberOfSessions
        
        sessionAllowsEditing =
            plan.treatmentSessions.isEmpty
            || !plan.treatmentSessions.allSatisfy { $0.isInvoiced || $0.isPaid }
        
        therapyPlanAllowsSendingAppointments = plan.treatmentSessions.contains {
            $0.draft || $0.isPlanned
        }
        
        therapyPlanAllowsSendingPlannedAppointments = plan.treatmentSessions
            .contains { $0.isPlanned }
        
        therapyPlanAllowsCancelingAppointments = plan.treatmentSessions.contains
        { $0.isScheduled }
    }

    private func sendIcsAppointments(for sessions: [TreatmentSessions]) {
        guard let patientEmail = patient.emailAddresses.first?.value else {
            GlobalToast.show(
                NSLocalizedString("noEmailFound", comment: "No email found")
            )
            return
        }

        var events: [IcsEventData] = []
        var updatedSessions: [UUID: TreatmentSessions] = [:]

        for session in sessions {
            var mutableSession = session

            if mutableSession.icsUid == nil {
                mutableSession.icsUid = UUID().uuidString
                mutableSession.icsSequence = 0
            }

            // 🧠 Erzeuge IcsEventData mit ATTENDEE
            let event = IcsGenerator.mapSessionToIcsEvent(
                &mutableSession,
                attendee: patientEmail
            )
            events.append(event)

            // Speichere vorbereitete Version (noch nicht anwenden)
            updatedSessions[mutableSession.id] = mutableSession
        }

        guard
            let icsData = IcsGenerator.generateCalendarData(
                events: events,
                organizerEmail: AppGlobals.shared.practiceInfo.email
            )
        else {
            GlobalToast.show(
                NSLocalizedString(
                    "icsFileNotValid",
                    comment: "ICS file not valid"
                )
            )
            return
        }
                
        let subject = sessions.count == 1
        ? (patient.firstnameTerms
                ? NSLocalizedString("appointmentSubjectSingleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentSubjectSingle", comment: ""))
        : (patient.firstnameTerms
                ? NSLocalizedString("appointmentSubjectMultipleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentSubjectMultiple", comment: ""))

        let introductoryText = patient.firstnameTerms
                ? NSLocalizedString("introText1FirstnameTerms", comment: "") + patient.firstname
                : NSLocalizedString("introText1", comment: "") + patient.fullName
                
        let appointmentBody = sessions.count == 1
        ? (patient.firstnameTerms
                ? NSLocalizedString("appointmentBodySingleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentBodySingle", comment: ""))
        : (patient.firstnameTerms
                ? NSLocalizedString("appointmentBodyMultipleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentBodyMultiple", comment: ""))

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEEE") // voller Wochentag

        let dateOnly = DateFormatter()
        dateOnly.locale = .current
        dateOnly.dateStyle = .medium
        dateOnly.timeStyle = .none

        let timeOnly = DateFormatter()
        timeOnly.locale = .current
        timeOnly.dateStyle = .none
        timeOnly.timeStyle = .short

        let datesList = sessions.map { session in
            let weekday = weekdayFormatter.string(from: session.date)

            let start = IcsGenerator.combine(date: session.date, time: session.startTime)
            let end   = IcsGenerator.combine(date: session.date, time: session.endTime)

            let location = "\(session.address.street), \(session.address.postalCode) \(session.address.city)"

            // "Wochentag - Datum Uhrzeit(von) - Uhrzeit(bis)"
            let line = "• \(weekday) - \(dateOnly.string(from: start)): \(timeOnly.string(from: start)) - \(timeOnly.string(from: end)) \(NSLocalizedString("oclock", comment: "")) \n  \(location)"
            return line
        }.joined(separator: "\n\n")
        
        IcsMailPresenter.presentMail(
            recipient: patientEmail,
            subject: subject,
            message: """
                \(introductoryText),

                \(appointmentBody)

                \(datesList)

                """,

            //            \(NSLocalizedString("manyGreetings", comment: "Many greetings")),
            //            \(AppGlobals.shared.practiceInfo.name)
            //            """,

            attachments: [
                (
                    filename: "Therapie-Termine.ics",
                    data: icsData
                )
            ],
            sender: AppGlobals.shared.practiceInfo.email,
            onResult: { result in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let toastText: String
                    switch result {
                    case .sent:
                        toastText = NSLocalizedString("mailSent", comment: "Mail sent")
                        Task { @MainActor in
                            // Reihenfolge & Positionen der verschickten Sessions bestimmen
                            let orderedSent = sessions.sorted { $0.startTime < $1.startTime }
                            let total = orderedSent.count
                            let positionById: [UUID: Int] = Dictionary(uniqueKeysWithValues:
                                orderedSent.enumerated().map { ($0.element.id, $0.offset + 1) }
                            )

                            for (id, updated) in updatedSessions {
                                if let idx = plan.treatmentSessions.firstIndex(where: { $0.id == id }) {
                                    // Status & ICS-Felder aktualisieren
                                    plan.treatmentSessions[idx].setStatus(.scheduled)
                                    plan.treatmentSessions[idx].icsUid = updated.icsUid
                                    plan.treatmentSessions[idx].icsSequence = updated.icsSequence

                                    // Lokalen Kalender-Eintrag mit (x/total) erzeugen
                                    let pos = positionById[id]
                                    LocalCalendarManager.createEvent(
                                        for: plan.treatmentSessions[idx],
                                        position: pos,
                                        total: total
                                    ) { eventId in
                                        // Event-Identifier sichern, falls du ihn für späteres Löschen brauchst
                                        if let eventId = eventId {
                                            Task { @MainActor in
                                                if let safeIdx = plan.treatmentSessions.firstIndex(where: { $0.id == id }) {
                                                    plan.treatmentSessions[safeIdx].localCalendarEventId = eventId
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            onUpdatePlan?(plan)
                            updateSessionEditability(for: plan)
                            savePlan()
                        }
                    case .cancelled:
                        toastText = NSLocalizedString(
                            "mailCancelled",
                            comment: "Mail cancelled"
                        )
                    case .saved:
                        toastText = NSLocalizedString(
                            "mailSaved",
                            comment: "Mail saved"
                        )
                    case .failed:
                        toastText = NSLocalizedString(
                            "mailFailed",
                            comment: "Mail failed"
                        )
                    @unknown default:
                        toastText = NSLocalizedString(
                            "mailUnknown",
                            comment: "Unknown mail result"
                        )
                    }
                    GlobalToast.show(toastText)
                }
            }
        )
    }

    private func cancelIcsAppointments(for sessions: [TreatmentSessions]) {
        guard let patientEmail = patient.emailAddresses.first?.value else {
            GlobalToast.show(
                NSLocalizedString("noEmailFound", comment: "No email found")
            )
            return
        }

        var attachments: [(filename: String, data: Data)] = []
        var updatedSessions: [UUID: TreatmentSessions] = [:]

        for session in sessions {
            guard let uid = session.icsUid else { continue }

            let start = IcsGenerator.combine(
                date: session.date,
                time: session.startTime
            )
            let end = IcsGenerator.combine(
                date: session.date,
                time: session.endTime
            )

            let location = [
                session.address.street,
                "\(session.address.postalCode) \(session.address.city)",
                session.address.country,
            ]
            .compactMap { $0 }
            .joined(separator: ", ")

            let sequence = (session.icsSequence ?? 0) + 1

            let cancelIcs = IcsGenerator.generateCancellation(
                uid: uid,
                start: start,
                end: end,
                summary: NSLocalizedString(
                    "icsEventDescription",
                    comment: "ics event description"
                ),
                location: location,
                attendee: patientEmail,
                sequence: sequence
            )

            guard let icsData = cancelIcs.data(using: .utf8) else { continue }

            let filename = "Absage-\(session.date.formatted(.iso8601)).ics"
            attachments.append((filename, icsData))

            // Nur merken, noch NICHT ändern
            if let index = plan.treatmentSessions.firstIndex(where: {
                $0.id == session.id
            }) {
                var updated = plan.treatmentSessions[index]
                updated.setStatus(.draft)
                updated.localCalendarEventId = nil
                updatedSessions[updated.id] = updated
            }
        }

        guard !attachments.isEmpty else {
            GlobalToast.show(
                NSLocalizedString("mailFailed", comment: "Mail failed")
            )
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let subject = sessions.count == 1
        ? (patient.firstnameTerms
                ? NSLocalizedString("appointmentCancelledSubjectSingleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentSubjectSingle", comment: ""))
        : (patient.firstnameTerms
                ? NSLocalizedString("appointmentCancelledSubjectMultipleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentCancelledSubjectMultiple", comment: ""))

        let introductoryText = patient.firstnameTerms
                ? NSLocalizedString("introText1FirstnameTerms", comment: "") + patient.firstname
                : NSLocalizedString("introText1", comment: "") + patient.fullName
                
        let appointmentCancelledBody = sessions.count == 1
        ? (patient.firstnameTerms
                ? NSLocalizedString("appointmentCancelledBodySingleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentCancelledBodySingle", comment: ""))
        : (patient.firstnameTerms
                ? NSLocalizedString("appointmentCancelledBodyMultipleFirstnameTerms", comment: "")
                : NSLocalizedString("appointmentCancelledBodyMultiple", comment: ""))

        let datesList = sessions.map { session in
            let weekday = session.date.formatted(.dateTime.weekday(.wide).locale(Locale.current))
            
            let start = IcsGenerator.combine(
                date: session.date,
                time: session.startTime
            )
            let end = IcsGenerator.combine(
                date: session.date,
                time: session.endTime
            )
            let location =
                "\(session.address.street), \(session.address.postalCode) \(session.address.city)"
            return
                "• \(weekday) - \(dateFormatter.string(from: start)) – \(dateFormatter.string(from: end))\n  \(location)"
        }.joined(separator: "\n\n")
        
        IcsMailPresenter.presentMail(
            recipient: patientEmail,
            subject: subject,
            message: """
                \(introductoryText),

                \(appointmentCancelledBody)
                
                \(datesList)
                
                """,

//                \(NSLocalizedString("manyGreetings", comment: "Many greetings")),
//                \(AppGlobals.shared.practiceInfo.name)
//                """,
            
            attachments: attachments,
            sender: AppGlobals.shared.practiceInfo.email,
            onResult: { result in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let toastText: String
                    switch result {
                    case .sent:
                        toastText = NSLocalizedString(
                            "mailSent",
                            comment: "Mail sent"
                        )
                        Task { @MainActor in
                            for (id, updated) in updatedSessions {
                                if let index = plan.treatmentSessions
                                    .firstIndex(where: { $0.id == id })
                                {
                                    plan.treatmentSessions[index] = updated

                                    LocalCalendarManager.deleteEvent(
                                        identifier: updated
                                            .localCalendarEventId,
                                        uid: updated.icsUid
                                    )
                                }
                            }
                            onUpdatePlan?(plan)
                            updateSessionEditability(for: plan)
                            savePlan()
                        }
                    case .cancelled:
                        toastText = NSLocalizedString(
                            "mailCancelled",
                            comment: "Mail cancelled"
                        )
                    case .saved:
                        toastText = NSLocalizedString(
                            "mailSaved",
                            comment: "Mail saved"
                        )
                    case .failed:
                        toastText = NSLocalizedString(
                            "mailFailed",
                            comment: "Mail failed"
                        )
                    @unknown default:
                        toastText = NSLocalizedString(
                            "mailUnknown",
                            comment: "Unknown result"
                        )
                    }
                    GlobalToast.show(toastText)
                }
            }
        )
    }

    private func updateAllOtherSessions(for patient: Patient) {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("patients")

        var sessionsFromSamePatient: [TreatmentSessions] = []
        var sessionsFromOtherPatients: [TreatmentSessions] = []

        do {
            let folders = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil
            )

            for folder in folders {
                let fileURL = folder.appendingPathComponent("patient.json")
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    continue
                }

                let data: Data
                do {
                    data = try Data(contentsOf: fileURL)
                } catch {
                    continue
                }

                let patientFile: PatientFile
                do {
                    patientFile = try JSONDecoder().decode(
                        PatientFile.self,
                        from: data
                    )
                } catch {
                    continue
                }

                let loadedPatient = patientFile.patient

                for therapy in loadedPatient.therapies.compactMap({ $0 }) {
                    for planCandidate in therapy.therapyPlans {
                        guard planCandidate.id != plan.id else { continue }

                        for session in planCandidate.treatmentSessions {
                            guard session.therapistId == plan.therapistId else {
                                continue
                            }

                            let isRelevant = !session.draft
                            guard isRelevant else { continue }

                            if loadedPatient.id == patient.id {
                                sessionsFromSamePatient.append(session)
                            } else {
                                sessionsFromOtherPatients.append(session)
                            }
                        }
                    }
                }
            }

            self.ownSessions = sessionsFromSamePatient
            self.otherSessions = sessionsFromOtherPatients

        } catch {
            self.ownSessions = []
            self.otherSessions = []
        }
    }
    
    /// Darstellung "Name (Menge Einheit)" mit Fallbacks
    private func serviceDisplayString(for service: TreatmentService) -> String {
        let qty = service.quantity ?? 0
        let unit = service.unit ?? ""
        let qtyUnit = unit.isEmpty ? "\(qty)" : "\(qty) \(unit)"
        return "\(service.de) (\(qtyUnit))"
    }

    /// Service in den Plan aufnehmen
    private func addService(_ service: TreatmentService) {
        guard !plan.treatmentServiceIds.contains(service.internalId) else { return }
        plan.treatmentServiceIds.append(service.internalId)
    }

    /// Service aus dem Plan entfernen
    private func removeService(_ service: TreatmentService) {
        plan.treatmentServiceIds.removeAll { $0 == service.internalId }
    }
}

extension TherapyPlanDetailView: TravelTimeValidator {
    func confirmTravelTime(
        estimatedMinutes: Int,
        origin: Address,
        destination: Address
    ) async -> Int? {
        if origin.isSameLocation(
            as: AppGlobals.shared.practiceInfo.startAddress
        ) || origin.isSameLocation(as: destination) {
            return estimatedMinutes  // keine Validierung nötig
        } else {
            return await withCheckedContinuation { continuation in
                travelTimeRequest = TravelTimeRequest(
                    origin: origin,
                    destination: destination,
                    estimated: estimatedMinutes,
                    continuation: continuation
                )
            }
        }
    }
}
