//
//  TissueStatusEntryRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 10.05.25.
//

import SwiftUI

struct TissueStatusEntryRow: View {
    @Binding var entry: TissueStatusEntry
    let availableTissues: [Tissues]
    let availableTissueStates: [TissueStates]
    let availablePainQualities: [PainQualities]
    let onEdited: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Gewebe
            HStack {
                Text(NSLocalizedString("tissue", comment: "Tissue"))
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: $entry.tissue) {
                    ForEach(availableTissues, id: \.id) { tissue in
                        Text(tissue.localized()).tag(tissue)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 300, alignment: .trailing)
                .onChange(of: entry.tissue) { _, _ in onEdited() }
            }

            // Gewebezustand
            HStack {
                Text(NSLocalizedString("tissueState", comment: "Tissue state"))
                    .frame(width: 120, alignment: .leading)

                Picker(
                    "",
                    selection: Binding(
                        get: { entry.tissueStates },
                        set: {
                            entry.tissueStates = $0
                            onEdited()
                        }
                    )
                ) {
                    Text("–").tag(TissueStates?.none)
                    ForEach(availableTissueStates, id: \.id) { state in
                        Text(state.localized()).tag(Optional(state))
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 300, alignment: .trailing)
            }

            // Schmerzqualität & -stärke
            HStack {
                // Qualität
                HStack {
                    Text(NSLocalizedString("pain", comment: "Pain"))
                        .frame(width: 120, alignment: .leading)

                    Picker(
                        "",
                        selection: Binding(
                            get: { entry.painQuality },
                            set: {
                                entry.painQuality = $0
                                onEdited()
                            }
                        )
                    ) {
                        Text("–").tag(PainQualities?.none)
                        ForEach(availablePainQualities, id: \.id) { pq in
                            Text(pq.localized()).tag(Optional(pq))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .frame(width: 300, alignment: .trailing)
                }

                // Stärke
                HStack {
                    Text("\(entry.painLevel?.value ?? 0)")
                        .frame(width: 70, alignment: .leading)

                    Spacer()

                    Slider(
                        value: Binding(
                            get: { Double(entry.painLevel?.value ?? 0) },
                            set: { entry.painLevel = PainLevels(Int($0)) }
                        ),
                        in: 0...10,
                        step: 1
                    ) { editing in
                        if !editing { onEdited() }
                    }
                }
            }

            // Notizen
            TextField(
                NSLocalizedString("notes", comment: "Notes"),
                text: Binding($entry.notes, default: "")
            )
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit { onEdited() }
        }
    }
}
