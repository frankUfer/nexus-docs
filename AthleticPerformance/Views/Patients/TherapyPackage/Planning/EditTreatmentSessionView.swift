//
//  EditTreatmentSessionView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.05.25.
//

import SwiftUI

struct EditTreatmentSessionView: View {
    @State private var tempSession: TreatmentSessions
    let patient: Patient
    let allServices: [TreatmentService]
    let availableTherapists: [Therapists]
    let availableAddresses: [Address]
    let allOtherSessions: [TreatmentSessions]
    let availability: [AvailabilitySlot]
    let validator: TravelTimeValidator
    let onCommit: (TreatmentSessions) -> Void

    @State private var selectedServiceId: UUID?
    @State private var durationMinutes: Int = 0
    @State private var lastEdited: EditSource? = nil
    @State private var showAvailabilityWarning = false
    @State private var availabilityConfirmed = false

    @State private var showAddressPicker = false
    @State private var selectedAddress: Address? = nil
    @State private var showAddAddressForm = false

    private let originalSession: TreatmentSessions

    private enum EditSource {
        case start, end, remedy
    }

    init(
        session: TreatmentSessions,
        patient: Patient,
        allServices: [TreatmentService],
        availableTherapists: [Therapists],
        availableAddresses: [Address],
        allOtherSessions: [TreatmentSessions],
        availability: [AvailabilitySlot],
        validator: TravelTimeValidator,
        onCommit: @escaping (TreatmentSessions) -> Void
    ) {
        self._tempSession = State(initialValue: session)
        self.originalSession = session
        self.patient = patient
        self._tempSession = State(initialValue: session)
        self.allServices = allServices
        self.availableTherapists = availableTherapists
        self.availableAddresses = availableAddresses
        self.allOtherSessions = allOtherSessions
        self.availability = availability
        self.validator = validator
        self.onCommit = onCommit

        let minutes = session.treatmentServiceIds
            .compactMap { id in allServices.first(where: { $0.internalId == id }) }
            .filter { $0.unit == "Min" }
            .compactMap { $0.quantity }
            .reduce(0, +)
        self._durationMinutes = State(initialValue: minutes)
    }

    private var patientAddresses: [Address] {
        patient.addresses.map(\.value)
    }

    // MARK: - Body

    var body: some View {
        Form {
            dateTimeSection
            locationSection
            therapistSection
            remediesSection
        }
        .navigationTitle(NSLocalizedString("editSession", comment: "Edit session"))
        .toolbar { leadingStatusToolbar }
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("confirm", comment: "Confirm")) {
                        Task { await validateAndCommitChanges() }
                    }
                }
            }
        }
        .alert(isPresented: $showAvailabilityWarning) { availabilityAlert }
        .sheet(isPresented: $showAddressPicker) { addressPickerSheet }
        .sheet(isPresented: $showAddAddressForm) { addAddressFormSheet }
        .onAppear {
            selectedAddress = tempSession.address
        }
    }

    // MARK: - Sections

    private var dateTimeSection: some View {
        Section(header: Text(NSLocalizedString("dateTime", comment: "Date & time"))) {
            HStack {
                Text(NSLocalizedString("date", comment: "Date"))
                    .foregroundColor(.primary)
                Spacer()
                Text(tempSession.date.formatted(.dateTime.weekday(.wide).locale(Locale.current)))
                    .foregroundColor(.secondary)
                DatePicker("", selection: $tempSession.date, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: tempSession.date) { _, newDate in
                        adjustDateComponents(newDate)
                    }
            }

            DatePicker(NSLocalizedString("start", comment: "Start"), selection: $tempSession.startTime, displayedComponents: .hourAndMinute)
                .onChange(of: tempSession.startTime) { _, newValue in
                    adjustStartTime(newValue)
                }

            DatePicker(NSLocalizedString("stop", comment: "Stop"), selection: $tempSession.endTime, displayedComponents: .hourAndMinute)
                .onChange(of: tempSession.endTime) { _, newValue in
                    adjustEndTime(newValue)
                }

            HStack {
                Text(NSLocalizedString("duration", comment: "Duration")).foregroundColor(.gray)
                Spacer()
                Text("\(sessionDurationMinutes) min").foregroundColor(.gray)
            }
        }
    }

    private var locationSection: some View {
        Section(header: Text(NSLocalizedString("location", comment: "Location"))) {
            Button {
                showAddressPicker = true
            } label: {
                HStack {
                    Text(NSLocalizedString("address", comment: "Address"))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(
                        (selectedAddress ?? tempSession.address)?.fullDescription
                            ?? NSLocalizedString("selectAddress", comment: "Select Address")
                    )
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private var therapistSection: some View {
        Section(header: Text(NSLocalizedString("therapist", comment: "Therapist"))) {
            Picker(NSLocalizedString("therapist", comment: "Therapist"), selection: $tempSession.therapistId) {
                ForEach(availableTherapists, id: \.id) { therapist in
                    Text(therapist.fullName).tag(therapist.id)
                }
            }
        }
    }

    private var remediesSection: some View {
        Section(header: Text(NSLocalizedString("remedies", comment: "Remedies"))) {
            ForEach(tempSession.treatmentServiceIds, id: \.self) { id in
                if let service = allServices.first(where: { $0.internalId == id }) {
                    HStack {
                        Text("\(service.de) – \(service.quantity ?? 0) \(service.unit ?? "")")
                        Spacer()
                        Button(role: .destructive) {
                            tempSession.treatmentServiceIds.removeAll { $0 == id }
                            updateDurationFromRemedies()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                    }
                }
            }

            if availableServiceOptions.count > 0 {
                Picker(NSLocalizedString("addRemedy", comment: "Add remedy"), selection: $selectedServiceId) {
                    Text("–").tag(UUID?.none)
                    ForEach(availableServiceOptions, id: \.self) { id in
                        if let service = allServices.first(where: { $0.internalId == id }) {
                            Text(service.de).tag(Optional(id))
                        }
                    }
                }
                .onChange(of: selectedServiceId) { _, newValue in
                    if let newId = newValue {
                        tempSession.treatmentServiceIds.append(newId)
                        selectedServiceId = nil
                        updateDurationFromRemedies()
                    }
                }
            }
        }
    }

    // MARK: - Sheets & Alerts

    private var availabilityAlert: Alert {
        Alert(
            title: Text(NSLocalizedString("warning", comment: "Warning")),
            message: Text(NSLocalizedString("outsideAvailability", comment: "Selected time is outside therapist's availability. Proceed?")),
            primaryButton: .default(Text(NSLocalizedString("ok", comment: "Ok"))) {
                Task { await validateAndCommitChanges(force: true) }
            },
            secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
        )
    }

    private var addressPickerSheet: some View {
        NavigationView {
            AddressSelectionView(
                patientAddresses: patientAddresses,
                onSelect: { address in
                    selectedAddress = address
                    tempSession.address = address
                },
                onDelete: { address in deletePublicAddress(address) },
                onAddNew: { showAddAddressForm = true }
        
            )
        }
    }

    private var addAddressFormSheet: some View {
        NavigationView {
            AddNewPublicAddressView(
                onSave: { newAddress in
                    saveNewPublicAddress(newAddress)
                    selectedAddress = newAddress.address
                    tempSession.address = newAddress.address
                    showAddAddressForm = false
                },
                onCancel: { showAddAddressForm = false }
            )
        }
    }

    // MARK: - Helpers

    private func adjustDateComponents(_ newDate: Date) {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: tempSession.startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: tempSession.endTime)

        tempSession.startTime = calendar.date(
            bySettingHour: startComponents.hour ?? 0,
            minute: startComponents.minute ?? 0,
            second: 0,
            of: newDate
        ) ?? tempSession.startTime

        tempSession.endTime = calendar.date(
            bySettingHour: endComponents.hour ?? 0,
            minute: endComponents.minute ?? 0,
            second: 0,
            of: newDate
        ) ?? tempSession.endTime
    }

    private func adjustStartTime(_ newValue: Date) {
        if lastEdited != .end {
            tempSession.endTime = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: newValue) ?? newValue
            lastEdited = .start
        } else {
            lastEdited = nil
        }
    }

    private func adjustEndTime(_ newValue: Date) {
        guard lastEdited != .start else { return }
        lastEdited = .end
        tempSession.startTime = Calendar.current.date(byAdding: .minute, value: -durationMinutes, to: newValue) ?? newValue
    }

    private func updateDurationFromRemedies() {
        let newDuration = tempSession.treatmentServiceIds
            .compactMap { id in allServices.first(where: { $0.internalId == id }) }
            .filter { $0.unit == "Min" }
            .compactMap { $0.quantity }
            .reduce(0, +)

        durationMinutes = newDuration
        lastEdited = .remedy
        tempSession.endTime = Calendar.current.date(byAdding: .minute, value: newDuration, to: tempSession.startTime) ?? tempSession.startTime
    }

    private var sessionDurationMinutes: Int {
        let diff = tempSession.endTime.timeIntervalSince(tempSession.startTime)
        return max(Int(diff / 60), 0)
    }

    private var availableServiceOptions: [UUID] {
        allServices.map { $0.internalId }.filter { !tempSession.treatmentServiceIds.contains($0) }
    }

    private var hasChanges: Bool {
        tempSession != originalSession
    }

    private var leadingStatusToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if tempSession.draft || tempSession.isPlanned {
                HStack(spacing: 8) {
                    Button { tempSession.setStatus(.draft) } label: {
                        Text(NSLocalizedString("draft", comment: "Draft"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tempSession.draft ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(tempSession.draft ? .white : .primary)
                            .cornerRadius(8)
                    }

                    Button { tempSession.setStatus(.planned) } label: {
                        Text(NSLocalizedString("planned", comment: "Planned"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tempSession.isPlanned ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(tempSession.isPlanned ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            } else {
                Text(
                    tempSession.isDone ? NSLocalizedString("done", comment: "Done")
                    : tempSession.isScheduled ? NSLocalizedString("scheduled", comment: "Scheduled")
                    : tempSession.isInvoiced ? NSLocalizedString("invoiced", comment: "Invoiced")
                    : NSLocalizedString("unknownStatus", comment: "Unknown Status")
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }

    private func validateAndCommitChanges(force: Bool = false) async {
        if let selected = selectedAddress {
            tempSession.address = selected
        }

        let travelManager = TravelTimeManager.shared

        let sortedSessions = allOtherSessions
            .filter { Calendar.current.isDate($0.startTime, inSameDayAs: tempSession.startTime) }
            .sorted(by: { $0.startTime < $1.startTime })

        let previous = sortedSessions.last(where: { $0.endTime <= tempSession.startTime })
        let next = sortedSessions.first(where: { $0.startTime >= tempSession.endTime })

        let origin = previous?.address ?? AppGlobals.shared.practiceInfo.startAddress

        let travelTimeBefore = await travelManager.calculateConfirmedTravelTime(
            from: origin,
            to: tempSession.address,
            validator: validator,
            requireConfirmation: false
        ) ?? 0

        var travelTimeAfter: TimeInterval = 0
        if let next = next {
            travelTimeAfter = await travelManager.calculateConfirmedTravelTime(
                from: tempSession.address,
                to: next.address,
                validator: validator,
                requireConfirmation: false
            ) ?? 0
        }

        let travelStart = tempSession.startTime.addingTimeInterval(-travelTimeBefore)
        let travelEnd = tempSession.endTime.addingTimeInterval(travelTimeAfter)

        let slotConflict = sortedSessions.contains {
            $0.overlaps(with: travelStart, travelEnd)
        }

        if slotConflict && !force && !availabilityConfirmed {
            showAvailabilityWarning = true
            return
        }

        if !force {
            let sameDaySlots = availability.filter {
                Calendar.current.isDate($0.start, inSameDayAs: tempSession.startTime)
            }
            let isWithinAnySlot = sameDaySlots.contains {
                $0.contains(start: tempSession.startTime, end: tempSession.endTime)
            }
            if sameDaySlots.isEmpty || !isWithinAnySlot {
                DispatchQueue.main.async {
                    self.showAvailabilityWarning = true
                }
                return
            }
        }

        onCommit(tempSession)
    }

    private func saveNewPublicAddress(_ new: PublicAddress) {
        var file = PublicAddressFile(version: 1, items: AppGlobals.shared.publicAddresses)
        file.items.append(new)

        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("resources/parameter")
                .appendingPathComponent(ParameterFile.publicAddresses.rawValue)

            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)

            AppGlobals.shared.publicAddresses = file.items
        } catch {
            let message = "\(String(format: NSLocalizedString("errorSavingNewAddress", comment: "Error saving new address"))): \(error)"
          showErrorAlert(errorMessage: message)
        }
    }

    private func deletePublicAddress(_ address: PublicAddress) {
        var file = PublicAddressFile(version: 1, items: AppGlobals.shared.publicAddresses)
        file.items.removeAll { $0.id == address.id }

        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("resources/parameter")
                .appendingPathComponent(ParameterFile.publicAddresses.rawValue)

            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)

            AppGlobals.shared.publicAddresses = file.items
        } catch {
            let message = "\(String(format: NSLocalizedString("errorDeletingPublicAddress", comment: "Error deleting public address"))): \(error)"
          showErrorAlert(errorMessage: message)
        }
    }
}
