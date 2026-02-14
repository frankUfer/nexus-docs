//
//  TherapyDiagnosisListView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI

struct TherapyDiagnosisListView: View {
    @Binding var therapy: Therapy
    @Binding var patient: Patient
    @EnvironmentObject var patientStore: PatientStore

    @State private var isDirty = false

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {
                Button {
                    let newDiagnosis = Diagnosis.empty(with: therapy.id)
                    therapy.diagnoses.append(newDiagnosis)
                    isDirty = true
                } label: {
                    Label(
                        NSLocalizedString(
                            "addDiagnosis",
                            comment: "Add Diagnosis"
                        ),
                        systemImage: "plus"
                    )
                }
                .foregroundColor(.addButton)
                .padding(.bottom)

                ForEach($therapy.diagnoses.sorted(by: \.date, descending: true))
                { $diagnosis in
                    VStack(alignment: .leading, spacing: 16) {
                        DiagnosisCardView(
                            diagnosis: $diagnosis,
                            onChange: {  // ⬅️ keine Speicherung hier
                                isDirty = true  // nur markieren
                            },
                            patientId: patient.id,
                            therapyId: therapy.id,
                            therapyPlans: therapy.therapyPlans.compactMap {
                                $0
                            },
                            patient: $patient
                        )
                        .environmentObject(patientStore)

                        Divider()
                            .frame(height: 2)
                            .background(Color.divider.opacity(0.5))
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding()
        }
        .onDisappear {
            if isDirty {
                patientStore.updatePatient(patient, waitUntilSaved: true)  // ⬅️ garantiert persistiert
                isDirty = false
            }
        }
    }
}

extension Binding
where
    Value: MutableCollection, Value: RandomAccessCollection,
    Value.Element: Identifiable
{
    func sorted<T: Comparable>(
        by keyPath: KeyPath<Value.Element, T>,
        descending: Bool = false
    ) -> [Binding<Value.Element>] {
        let sortedIndices = wrappedValue.indices.sorted {
            let lhs = wrappedValue[$0][keyPath: keyPath]
            let rhs = wrappedValue[$1][keyPath: keyPath]
            return descending ? lhs > rhs : lhs < rhs
        }
        return sortedIndices.map { self[$0] }
    }
}
