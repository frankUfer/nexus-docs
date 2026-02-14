//
//  JointStatusEntryRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

import SwiftUI

struct JointStatusEntryRow: View {
    @Binding var entry: JointStatusEntry
    let availableJoints: [Joints]
    let availableMovements: [JointMovementPattern]
    let availablePainQualities: [PainQualities]
    let availableEndFeelings: [EndFeelings]
    let onEdited: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Gelenk
            HStack {
                Text(NSLocalizedString("joint", comment: "Joint"))
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: $entry.joint) {
                    ForEach(availableJoints, id: \.id) { joint in
                        Text(joint.localized()).tag(joint)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 300, alignment: .trailing)
                .onChange(of: entry.joint) { _, _ in onEdited() }
            }

            // Bewegung + Wert
            HStack {
                HStack {
                    Text(NSLocalizedString("movement", comment: "Movement"))
                        .frame(width: 120, alignment: .leading)

                    Picker("", selection: $entry.movement) {
                        ForEach(availableMovements, id: \.id) { move in
                            Text(move.localized()).tag(move)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .frame(width: 300, alignment: .trailing)
                    .onChange(of: entry.movement) { _, _ in onEdited() }

                    Spacer()
                }

                movementValueView
            }

            // Schmerz
            HStack {
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

                    Spacer()
                }

                HStack {
                    Text("\(entry.painLevel?.value ?? 0)")
                        .frame(width: 70, alignment: .leading)

                    Spacer()

                    // Slider: Änderung erst bei Edit-Ende als „geändert“ markieren
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

            // Endgefühl
            HStack {
                Text(NSLocalizedString("endFeel", comment: "End feeling"))
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: Binding(
                    get: { entry.endFeeling },
                    set: { entry.endFeeling = $0; onEdited() }
                )) {
                    Text("–").tag(EndFeelings?.none)
                    ForEach(availableEndFeelings, id: \.id) { ef in
                        Text(ef.localized()).tag(Optional(ef))
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 300, alignment: .trailing)
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

    @ViewBuilder
    private var movementValueView: some View {
        let pattern = entry.movement

        if pattern.inputType == .slider {
            let min = pattern.min ?? 0
            let max = pattern.max ?? 100
            let step = pattern.step ?? 1

            HStack {
                Text(String(format: "%.0f", {
                    if case let .number(val) = entry.value { return val }
                    return min
                }()) + " \(pattern.unit ?? "")")
                .frame(width: 70, alignment: .leading)

                Spacer()

                Slider(
                    value: Binding(
                        get: {
                            if case let .number(val) = entry.value { return val }
                            return min
                        },
                        set: { entry.value = .number($0) }
                    ),
                    in: min...max,
                    step: step
                ) { editing in
                    if !editing { onEdited() }
                }
            }
        }
        else if pattern.inputType == .toggle {
            BoolSwitch(
                value: Binding(
                    get: {
                        if case let .boolean(b) = entry.value { return b }
                        return false
                    },
                    set: { entry.value = .boolean($0); onEdited() }
                ),
                label: NSLocalizedString("possible", comment: "Possible")
            )
        }
        else {
            Text("⚠️ \(NSLocalizedString("unknown", comment: "Unknown"))")
                .foregroundColor(.secondary)
        }
    }
}
