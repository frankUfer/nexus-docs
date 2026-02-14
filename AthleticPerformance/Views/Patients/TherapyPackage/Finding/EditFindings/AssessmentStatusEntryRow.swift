//
//  AssessmentStatusEntryRow.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 03.10.25.
//

import SwiftUI

struct AssessmentStatusEntryRow: View {
    @Binding var entry: AssessmentStatusEntry
    let availableAssessments: [Assessments]
    let onEdited: () -> Void
    var isEditable: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 12) {
                Picker(NSLocalizedString("assessment", comment: "Assessment"),
                       selection: $entry.assessmentId) {
                    ForEach(availableAssessments, id: \.id) { a in
                        Text(a.localized()).tag(a.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .onChange(of: entry.assessmentId) { _, _ in onEdited() }

                BoolSwitchWoSpacer(value: $entry.finding, label: "")
                    .onChange(of: entry.finding) { _, _ in onEdited() }
            }

            // Beschreibung / Notes
            TextField("",
                      text: $entry.description)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit { onEdited() }
        }
    }
}
