//
//  MultiPatientListView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 13.06.25.
//

import SwiftUI

struct MultiPatientListView: View {
    @Binding var selectedPatientIDs: Set<UUID>
    @Binding var refreshTrigger: UUID
    @ObservedObject var patientStore: PatientStore 
    var showContextMenu: Bool = true
    var onSelectPatient: (Patient) -> Void
    @Binding var currentDate: Date
    @Binding var selectedView: CalendarViewType
    @Binding var showCalendar: Bool

    @State private var showDeleteConfirmation = false
    @State private var patientToDelete: Patient?

    private let calendar = Calendar.current

    var body: some View {
        List(selection: $selectedPatientIDs) {
            ForEach(groupedPatients, id: \.0) { section, patients in
                Section(header: Text(section)) {
                    ForEach(patients, id: \.id) { patient in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    "\(patient.lastname.isEmpty ? "…" : patient.lastname), \(patient.firstname.isEmpty ? "…" : patient.firstname)"
                                )
                                .foregroundColor(
                                    patient.isActive ? .primary : .gray
                                )

                                Text(
                                    patient.birthdate.formatted(
                                        date: .abbreviated,
                                        time: .omitted
                                    )
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            if !patient.isActive {
                                Label("", systemImage: "slash.circle")
                                    .foregroundColor(.gray)
                                    .help(
                                        NSLocalizedString(
                                            "inactivePatient",
                                            comment: "Inactive patient"
                                        )
                                    )
                            }

                            Spacer(minLength: 12)

                            if selectedPatientIDs.contains(patient.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }

                            if hasContractPDF(for: patient) {
                                Label("", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.positiveCheck)
                                    .help(
                                        NSLocalizedString(
                                            "contractAvailable",
                                            comment:
                                                "Treatment contract available"
                                        )
                                    )
                            } else {
                                Label("", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.negativeCheck)
                                    .help(
                                        NSLocalizedString(
                                            "contractMissing",
                                            comment:
                                                "Treatment contract missing"
                                        )
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedPatientIDs.contains(patient.id) {
                                selectedPatientIDs.remove(patient.id)
                            } else {
                                selectedPatientIDs.insert(patient.id)
                            }
                            onSelectPatient(patient)
                        }
                        .contextMenu {
                            contextMenuItems(for: patient)
                        }
                    }
                }
            }
            .id(refreshTrigger)
        }
        .navigationTitle(
            NSLocalizedString("patientsList", comment: "Patients List")
        )
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    selectedPatientIDs = []
                } label: {
                    Image(systemName: "doc")
                }
                .help(NSLocalizedString("deselectAll", comment: "Deselect all"))
                Spacer()
                Button {
                    selectedPatientIDs = Set(patientStore.patients.map(\.id))
                } label: {
                    Image(systemName: "doc.text")
                }
                .help(NSLocalizedString("selectAll", comment: "Select all"))
            }
        }
        .alert(
            NSLocalizedString("confirmDelete", comment: "Confirm Delete"),
            isPresented: $showDeleteConfirmation,
            presenting: patientToDelete
        ) { patient in
            Button(role: .destructive) {
                Task { await patientStore.deletePatient(patient) }
            } label: {
                Text(NSLocalizedString("delete", comment: "Delete"))
            }
            Button(
                NSLocalizedString("cancel", comment: "Cancel"),
                role: .cancel
            ) {}
        } message: { patient in
            Text(
                String(
                    format: NSLocalizedString(
                        "deleteConfirmationMessage",
                        comment: "Do you really want to delete %@ %@?"
                    ),
                    patient.fullName
                )
            )
        }
        .onChange(of: selectedPatientIDs) { _, _ in
            showCalendar = !selectedPatientIDs.isEmpty
            updateDateToNearestSessionIfNeeded()
        }
        .navigationDestination(isPresented: $showCalendar) {
            MultiPatientCalendarView(
                patients: patientStore.patients,  
                selectedPatientIds: selectedPatientIDs,
                currentDate: $currentDate,
                selectedView: $selectedView
            )
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for patient: Patient) -> some View {
        if !patient.phoneNumbers.isEmpty {
            Menu {
                ForEach(patient.phoneNumbers, id: \.value) { entry in
                    Button(
                        "\(NSLocalizedString(entry.label, comment: "")): \(entry.value)"
                    ) {
                        if let url = URL(string: "tel:\(entry.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } label: {
                Label(
                    NSLocalizedString("call", comment: "Call"),
                    systemImage: "phone"
                )
            }

            Menu {
                ForEach(patient.phoneNumbers, id: \.value) { entry in
                    Button(
                        "\(NSLocalizedString(entry.label, comment: "")): \(entry.value)"
                    ) {
                        if let url = URL(string: "sms:\(entry.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } label: {
                Label(
                    NSLocalizedString("sendMessage", comment: "Send message"),
                    systemImage: "message"
                )
            }

            Menu {
                ForEach(patient.phoneNumbers, id: \.value) { entry in
                    Button(
                        "\(NSLocalizedString(entry.label, comment: "")): \(entry.value)"
                    ) {
                        if let url = URL(string: "facetime:\(entry.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } label: {
                Label(
                    NSLocalizedString("videoCall", comment: "Video call"),
                    systemImage: "video"
                )
            }
        }

        if !patient.emailAddresses.isEmpty {
            Menu {
                ForEach(patient.emailAddresses, id: \.value) { entry in
                    Button(
                        "\(NSLocalizedString(entry.label, comment: "")): \(entry.value)"
                    ) {
                        if let url = URL(string: "mailto:\(entry.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } label: {
                Label(
                    NSLocalizedString("sendEmail", comment: "Send email"),
                    systemImage: "envelope"
                )
            }
        }

        Button {
            togglePatientStatus(patient)
        } label: {
            Label(
                patient.isActive
                    ? NSLocalizedString("deactivatePatient", comment: "")
                    : NSLocalizedString("activatePatient", comment: ""),
                systemImage: patient.isActive
                    ? "slash.circle" : "checkmark.circle"
            )
        }
        
        let blockers = patientStore.deletionBlockers(for: patient)
        if blockers.isEmpty {
            Divider()
            .background(Color.divider.opacity(0.5))

            Button(role: .destructive) {
                patientToDelete = patient
                showDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("deletePatient", comment: "Delete patient"), systemImage: "trash")
            }
        }
    }

    // MARK: - Utilities

    private func togglePatientStatus(_ patient: Patient) {
        patientStore.togglePatientStatus(for: patient.id)
    }

    private func hasContractPDF(for patient: Patient) -> Bool {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("patients")
            .appendingPathComponent(patient.id.uuidString)
            .appendingPathComponent("contract.pdf")
        return FileManager.default.fileExists(atPath: url.path)
    }

    private var groupedPatients: [(String, [Patient])] {
        let sorted = patientStore.patients.sorted {
            $0.lastname.localizedCaseInsensitiveCompare($1.lastname)
                == .orderedAscending
        }
        let grouped = Dictionary(grouping: sorted) {
            String($0.lastname.prefix(1)).uppercased()
        }
        return grouped.keys.sorted().map { key in
            (key, grouped[key] ?? [])
        }
    }

    private var sessionsForSelectedPatients: [TreatmentSessions] {
        patientStore.patients
            .filter { selectedPatientIDs.contains($0.id) }
            .flatMap { $0.therapies.compactMap { $0 } }
            .flatMap { $0.therapyPlans }
            .flatMap { $0.treatmentSessions }
    }

    private func updateDateToNearestSessionIfNeeded() {
        let sessions = sessionsForSelectedPatients

        // Gibt es eine Session am aktuellen Datum?
        if sessions.contains(where: {
            !$0.draft && calendar.isDate($0.startTime, inSameDayAs: currentDate)
        }) {
            return
        }

        // Nächste Session relativ zu currentDate finden
        let currentDayStart = calendar.startOfDay(for: currentDate)
        if let nearestSession = sessions.min(by: { lhs, rhs in
            let lhsDiff = abs(lhs.startTime.timeIntervalSince(currentDayStart))
            let rhsDiff = abs(rhs.startTime.timeIntervalSince(currentDayStart))
            return lhsDiff < rhsDiff
        }) {
            currentDate = calendar.startOfDay(for: nearestSession.startTime)
        }
    }
    
    private func localizedReasons(_ blockers: Set<PatientDeletionBlocker>) -> [String] {
        blockers.map {
            switch $0 {
            case .contractPDF:      return NSLocalizedString("contractAvailable", comment: "Treatment contract available")
            case .therapyAgreement: return NSLocalizedString("therapyAgreementExists", comment: "Therapy agreement exists")
            case .diagnoses:        return NSLocalizedString("hasDiagnoses", comment: "Diagnoses present")
            case .findings:         return NSLocalizedString("hasFindings", comment: "Findings present")
            case .therapyPlans:     return NSLocalizedString("hasTherapyPlans", comment: "Therapy plans present")
            case .sessions:         return NSLocalizedString("hasSessions", comment: "Sessions present")
            }
        }.sorted()
    }
}
