//
//  TissueStatusDisplayList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.10.25.
//

import SwiftUI

// MARK: - Read-only Liste (Tissues)
struct TissueStatusDisplayList: View {
    let entries: [TissueStatusEntry]
    let titleKey: String

    var body: some View {
        let labelKeys = [
            NSLocalizedString("bodySide", comment: "Body side"),
            NSLocalizedString("tissue", comment: "Tissue"),
            NSLocalizedString("tissueState", comment: "Tissue state"),
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
                    TissueStatusDisplayRow(
                        entry: entries[idx],
                        colWidth: colWidth
                    )

                    if idx < entries.indices.last! {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Read-only Einzelzeile (Tissue)
struct TissueStatusDisplayRow: View {
    let entry: TissueStatusEntry
    let colWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Kopf: Body side + Re-evaluation, im selben Stil wie Symptoms / Joint / Muscle
            HStack {
                labelRow(
                    NSLocalizedString("bodySide", comment: "Body side"),
                    entry.side?.localized ?? "–"
                )

                Spacer()

                BoolIndicatorWoSpacer(
                    value: entry.reevaluation,
                    label: NSLocalizedString("reevaluation", comment: "Re-evaluation")
                )
            }

            // Gewebe
            labelRow(
                NSLocalizedString("tissue", comment: "Tissue"),
                entry.tissue.localized()
            )

            // Gewebestatus
            labelRow(
                NSLocalizedString("tissueState", comment: "Tissue state"),
                entry.tissueStates?.localized() ?? "–"
            )

            // Schmerzblock (Qualität • Stärke), einzeilig wie bei Muscles / Joints / Symptoms
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

    // MARK: - Schmerzblock im Standard-Format ("Qualität • Level")
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

    // MARK: - Standardisierte Zeile (Key links, Value grau rechts)
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

    // MARK: - Helper
    private func clean(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }
}
