//
//  PatientListView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.03.25.
//

import LocalAuthentication
import SwiftUI

struct PatientListView: View {
    @Binding var refreshTrigger: UUID
    @ObservedObject var patientStore: PatientStore
    @EnvironmentObject var navigationStore: AppNavigationStore
    var showContextMenu: Bool = true
    var onSelectPatient: (Patient) -> Void

    @State private var showAddPatientView = false
    @State private var showDeleteConfirmation = false
    @State private var patientToDelete: Patient?
    @AppStorage("showOnlySelectedPatient") private var showOnlySelectedPatient =
        false
    @State private var authError: Bool = false

    private var filteredGroupedPatients: [(String, [Patient])] {
        if showOnlySelectedPatient,
            let selectedID = navigationStore.selectedPatientID,
            let selected = patientStore.patients.first(where: {
                $0.id == selectedID
            })
        {
            let key = String(selected.lastname.prefix(1)).uppercased()
            return [(key, [selected])]
        } else {
            return groupedPatients
        }
    }

    var body: some View {
        List(selection: $navigationStore.selectedPatientID) {
            ForEach(filteredGroupedPatients, id: \.0) { section, patients in
                Section(header: Text(section)) {
                    ForEach(patients, id: \.id) { patient in
                        Button {
                            navigationStore.selectedPatientID = patient.id
                            onSelectPatient(patient)
                        } label: {
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
                                
                                if hasContractPDF(for: patient) {
                                    Label("", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.positiveCheck)
                                        .help(NSLocalizedString("contractAvailable", comment: "Treament contract available"))
                                } else {
                                    Label("", systemImage: "xmark.circle.fill")
                                        .foregroundColor(.negativeCheck)
                                        .help(NSLocalizedString("contractMissing", comment: "Treatment contract missing"))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu(
                            showContextMenu
                                ? ContextMenu {
                                    contextMenuItems(for: patient)
                                } : nil
                        )
                    }
                }
            }
        }
        .id(refreshTrigger)
        .navigationTitle(
            NSLocalizedString("patientsList", comment: "Patients List")
        )
        .toolbar {
            // 1. Zentrum: Toggle-Button mit FaceID
            ToolbarItem(placement: .principal) {
                Button {
                    authenticateAndToggle()
                } label: {
                    Image(
                        systemName: showOnlySelectedPatient
                            ? "eye.slash" : "eye"
                    )
                    .foregroundColor(.accentColor)
                }
                .help(
                    showOnlySelectedPatient
                        ? NSLocalizedString(
                            "showAllPatients",
                            comment: "Show all patients"
                        )
                        : NSLocalizedString(
                            "showSelectedOnly",
                            comment: "Show selected patient only"
                        )
                )
            }

            // 2. Rechts: Plus-Button
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddPatientView = true }) {
                    Image(systemName: "plus")
                }
                .help(NSLocalizedString("addPatient", comment: "Add patient"))
            }
        }
        .sheet(isPresented: $showAddPatientView) {
            AddPatientView(patientStore: patientStore)  //, selectedPatientID: $navigationStore.selectedPatientID)
                .presentationDetents([.medium, .large])
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

        .alert(
            NSLocalizedString(
                "errorAuthentification",
                comment: "Error authentification"
            ),
            isPresented: $authError
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for patient: Patient) -> some View {
        // 📞 Telefon
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

            // 💬 SMS
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

            // 🎥 FaceTime
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

        // 📧 E-Mail
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

        // ✅ Aktiv/Inaktiv Umschalten
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
        var updated = patient
        updated.isActive.toggle()
        patientStore.updatePatient(updated)
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

    private func hasEmail(for patient: Patient) -> Bool {
        patient.emailAddresses.contains { !$0.value.isEmpty }
    }

    private func authenticateAndToggle() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) {
            let reason = NSLocalizedString(
                "authenticateToTogglePatientView",
                comment: "Authenticate to toggle patient view"
            )

            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        showOnlySelectedPatient.toggle()
                    } else {
                        authError = true
                    }
                }
            }
        } else {
            // Kein FaceID/TouchID verfügbar → Option: sofort togglen oder Hinweis zeigen
            authError = true
        }
    }

    private func localizedReasons(_ blockers: Set<PatientDeletionBlocker>)
        -> [String]
    {
        blockers.map {
            switch $0 {
            case .contractPDF:
                return NSLocalizedString(
                    "contractAvailable",
                    comment: "Treatment contract available"
                )
            case .therapyAgreement:
                return NSLocalizedString(
                    "therapyAgreementExists",
                    comment: "Therapy agreement exists"
                )
            case .diagnoses:
                return NSLocalizedString(
                    "hasDiagnoses",
                    comment: "Diagnoses present"
                )
            case .findings:
                return NSLocalizedString(
                    "hasFindings",
                    comment: "Findings present"
                )
            case .therapyPlans:
                return NSLocalizedString(
                    "hasTherapyPlans",
                    comment: "Therapy plans present"
                )
            case .sessions:
                return NSLocalizedString(
                    "hasSessions",
                    comment: "Sessions present"
                )
            }
        }.sorted()
    }
}
