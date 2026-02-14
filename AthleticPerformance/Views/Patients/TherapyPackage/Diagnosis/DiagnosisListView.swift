//
//  DiagnosisListView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI

struct DiagnosisListView: View {
    @Binding var therapy: Therapy
    @Binding var patient: Patient

    @State private var showEditor = false
    @EnvironmentObject var patientStore: PatientStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: { showEditor = true }) {
                Label(NSLocalizedString("addDiagnosis", comment: "Add Diagnosis"), systemImage: "plus")
            }
            .padding()
            .foregroundColor(.addButton)

            ForEach($therapy.diagnoses) { $diagnosis in
                DiagnosisCardView(
                    diagnosis: $diagnosis,
                    patientId: patient.id,
                    therapyId: therapy.id,
                    therapyPlans: therapy.therapyPlans.compactMap { $0 },
                    patient: $patient
                )
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showEditor) {
            DiagnosisEditorView(therapyId: therapy.id, patientId: patient.id) { newDiagnosis in
                therapy.diagnoses.append(newDiagnosis)
            }
        }
    }
}
