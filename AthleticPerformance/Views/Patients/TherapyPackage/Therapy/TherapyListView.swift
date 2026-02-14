//
//  TherapyListView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//

import SwiftUI

struct TherapyListView: View {
    let patient: Patient
    @Binding var selectedTherapy: Therapy?
    @Binding var isCreatingNewTherapy: Bool

    var body: some View {
        if patient.therapies.compactMap({ $0 }).isEmpty {
            Button {
                isCreatingNewTherapy = true
            } label: {
                Label(NSLocalizedString("addTherapy", comment: "Add Therapy"), systemImage: "plus")
                    .foregroundColor(.addButton)
            }
            .disabled(!patient.isActive)
            .help(patient.isActive ?
                  NSLocalizedString("createTherapy", comment: "Create a new therapy") :
                    NSLocalizedString("inactivePatientNoTherapy", comment: "Patient is inactive. Cannot create therapy."))
            .padding(.horizontal)
            .padding(.vertical, 20)
        } else {
            HStack {
                Spacer()
                Button {
                    isCreatingNewTherapy = true
                } label: {
                    Label(NSLocalizedString("addTherapy", comment: "Add Therapy"), systemImage: "plus")
                        .padding()
                        .foregroundColor(.addButton)
                }
                .disabled(!patient.isActive)
                Spacer()
            }
            
            SectionBox(title: "") {
                let sortedTherapies = patient.therapies
                    .compactMap { $0 }
                    .sorted { $0.startDate > $1.startDate }
                
                
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(sortedTherapies.enumerated()), id: \.element.id) { index, therapy in
                        Button {
                            selectedTherapy = therapy
                        } label: {
                            TherapyRowView(therapy: therapy)
                        }
                        
                        if sortedTherapies.count > 1 && index < sortedTherapies.count - 1 {
                            Divider()
                                .background(Color.divider.opacity(0.5))
                        }
                    }
                }
            }
        }
    }
}
