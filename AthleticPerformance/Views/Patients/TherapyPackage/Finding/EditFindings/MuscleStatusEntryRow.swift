//
//  MuscleStatusEntryRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 10.05.25.
//

import SwiftUI

struct MuscleStatusEntryRow: View {
    @Binding var entry: MuscleStatusEntry
    let availableMuscleGroups: [MuscleGroups]
    let availablePainQualities: [PainQualities]
    let onEdited: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Muskelgruppe
            HStack {
                Text(NSLocalizedString("muscles", comment: "Muscles"))
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: $entry.muscleGroup) {
                    ForEach(availableMuscleGroups, id: \.id) { group in
                        Text(group.localized()).tag(group)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 300, alignment: .trailing)
                .onChange(of: entry.muscleGroup) { _, _ in onEdited() }
            }

            // Muskeltonus
            HStack {
                Text(NSLocalizedString("muscleTone", comment: "Muscle tone"))
                    .frame(width: 120, alignment: .leading)

                Text("") // Platzhalter für ausgerichtetes Layout
                    .frame(width: 300, alignment: .trailing)

                Spacer()

                Text(entry.tone.displayValue)
                    .frame(width: 70, alignment: .leading)

                Spacer()

                Slider(
                    value: Binding(
                        get: { Double(entry.tone.rawValue) },
                        set: { entry.tone = MuscleTone.from(raw: Int($0)) }
                    ),
                    in: -3...3, step: 1
                ) { editing in
                    if !editing { onEdited() }
                }
            }

            // MFT-Wert
            HStack {
                Text(NSLocalizedString("mft", comment: "MFT"))
                    .frame(width: 120, alignment: .leading)

                Text("")
                    .frame(width: 300, alignment: .trailing)

                Text("\(entry.mft)")
                    .frame(width: 70, alignment: .leading)

                Spacer()

                Slider(
                    value: Binding(
                        get: { Double(entry.mft) },
                        set: { entry.mft = Int($0) }
                    ),
                    in: 1...5, step: 1
                )
                { editing in
                    if !editing { onEdited() }
                }
            }

            // Schmerzqualität & -stärke
            HStack {
                // Qualität
                HStack {
                    Text(NSLocalizedString("pain", comment: "Pain"))
                        .frame(width: 120, alignment: .leading)

                    Picker("", selection: Binding(
                        get: { entry.painQuality },
                        set: { entry.painQuality = $0; onEdited() }
                    )) {
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
                        in: 0...10, step: 1
                    ) { editing in
                        if !editing { onEdited() }
                    }
                }
            }

            // Notizen – Submit statt pro Keystroke dirty (ruhiger)
            TextField(NSLocalizedString("notes", comment: "Notes"),
                      text: Binding($entry.notes, default: ""))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit { onEdited() }
        }
    }
}
