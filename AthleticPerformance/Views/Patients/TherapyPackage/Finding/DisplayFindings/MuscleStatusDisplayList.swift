//
//  MuscleStatusDisplayList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.10.25.
//

import SwiftUI

// MARK: - Read-only Liste (Muscles)
struct MuscleStatusDisplayList: View {
    let entries: [MuscleStatusEntry]
    let titleKey: String

    var body: some View {
        let labelKeys = [
            NSLocalizedString("bodySide", comment: "Body side"),
            NSLocalizedString("muscle", comment: "Muscle"),
            NSLocalizedString("muscleTone", comment: "Muscle tone"),
            NSLocalizedString("mft", comment: "MFT"),
            NSLocalizedString("pain", comment: "Pain"),
            NSLocalizedString("notes", comment: "Notes")
        ]

        let colWidth = calculateColumnWidth(for: labelKeys)

        DisplaySectionBox(
            title: titleKey,
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(spacing: 16) {
                ForEach(entries.indices, id: \.self) { idx in
                    MuscleStatusDisplayRow(
                        entry: entries[idx],
                        colWidth: colWidth
                    )
                    if idx < entries.indices.last! { Divider() }
                }
            }
        }
    }
}

// MARK: - Read-only Einzelzeile (Muscle)
struct MuscleStatusDisplayRow: View {
    let entry: MuscleStatusEntry
    let colWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Kopfzeile: Seite (links) + Re-evaluation (rechts),
            // analog zu SymptomsDisplayRow / JointStatusDisplayRow
            HStack {
                labelRow(
                    NSLocalizedString("bodySide", comment: "Body side"),
                    entry.side.localized
                )

                Spacer()

                BoolIndicatorWoSpacer(
                    value: entry.reevaluation,
                    label: NSLocalizedString("reevaluation", comment: "Re-evaluation")
                )
            }

            // Muskelgruppe
            labelRow(
                NSLocalizedString("muscle", comment: "Muscle"),
                entry.muscleGroup.localized()
            )

            // Muskeltonus
            labelRow(
                NSLocalizedString("muscleTone", comment: "Muscle tone"),
                entry.tone.displayValue
            )

            // MFT-Wert
            labelRow(
                NSLocalizedString("mft", comment: "MFT"),
                "\(entry.mft)"
            )

            // Schmerzblock (Qualität • Stärke)
            painBlock

            // Notizen (optional)
            if let notes = clean(entry.notes) {
                labelRow(
                    NSLocalizedString("notes", comment: "Notes"),
                    notes
                )
            }
        }
    }

    // MARK: - Schmerzblock (Qualität • Stärke), Stil wie painBlock bei Symptoms
    @ViewBuilder
    private var painBlock: some View {
        let quality = entry.painQuality?.localized() ?? "–"
        let level   = entry.painLevel.map { "\($0.value)" } ?? "–"

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(NSLocalizedString("pain", comment: "Pain"))
                .frame(width: colWidth, alignment: .leading)

            Text("\(quality) • \(level)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - labelRow, gleiche Struktur wie bei Symptoms / Joint
    private func labelRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .frame(width: colWidth, alignment: .leading)

            Text(value)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Helper, gleich wie bei Symptoms
    private func clean(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }
}
