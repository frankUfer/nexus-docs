//
//  DiagnoseEditorView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI

struct DiagnosisEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var diagnoseDate: Date = Date()
    @State private var therapistId: Int = AppGlobals.shared.therapistId ?? 1
    @State private var showAlert: Bool = false

    let therapyId: UUID
    let patientId: UUID
    var onSave: (Diagnosis) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("diagnosisInformation", comment: "Diagnosis information"))) {
                    TextField(NSLocalizedString("diagnosisTitle", comment: "Diagnosis Title"), text: $title)

                    DatePicker(
                        NSLocalizedString("diagnosisDate", comment: "Diagnosis Date"),
                        selection: $diagnoseDate,
                        displayedComponents: [.date]
                    )
                }
                
                Section(header: Text(NSLocalizedString("therapist", comment: "Therapist"))) {
                    if let therapist = AppGlobals.shared.practiceInfo.therapists.first(where: { $0.id == therapistId }) {
                        Label("\(therapist.firstname) \(therapist.lastname)", systemImage: "person.fill")
                    } else {
                        Button(action: {
                            showAlert = true
                        }) {
                            Label(NSLocalizedString("therapistNotFound", comment: "Therapist not found."), systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.deleteButton)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("newDiagnosis", comment: "New Diagnosis"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.cancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("save", comment: "Save")) {
                        let newDiagnosis = Diagnosis.empty(with: therapyId)
                        onSave(newDiagnosis)
                        dismiss()
                    }
                    .foregroundColor(.done)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(NSLocalizedString("error", comment: "Error")),
                    message: Text(NSLocalizedString("therapistNotFound", comment: "Therapist not found.")),
                    dismissButton: .default(Text(NSLocalizedString("ok", comment: "Ok")))
                )
            }
        }
    }
}
