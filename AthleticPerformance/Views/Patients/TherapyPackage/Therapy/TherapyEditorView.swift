//
//  TherapyEditorView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 15.04.25.
//

import SwiftUI

struct TherapyEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var selectedBillingPeriod: BillingPeriod = .monthly
    @State private var therapistId: Int = AppGlobals.shared.therapistId ?? 1
    @State private var showAlert: Bool = false

    let patientId: UUID
    var onSave: (Therapy) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("therapyInformation", comment: "Therapy information"))) {
                    TextField(NSLocalizedString("therapyTitle", comment: "Therapy Title"), text: $title)

                    DatePicker(
                        NSLocalizedString("startDate", comment: "Start Date"),
                        selection: $startDate,
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
                                .foregroundColor(.error)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("newTherapy", comment: "New Therapy"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.cancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("save", comment: "Save")) {
                        let newTherapy = Therapy(
                            therapistId: therapistId,
                            patientId: patientId,
                            title: title,
                            startDate: startDate,
                        )
                        onSave(newTherapy)
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
