//
//  SymptomsDisplayList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.10.25.
//

import SwiftUI

// MARK: - Read-only Liste
struct SymptomsStatusDisplayList: View {
    let entries: [SymptomsStatusEntry]
    let titleKey: String

    var body: some View {
        let labelKeys = [
            NSLocalizedString("bodySide", comment: "Body side"),
            NSLocalizedString("bodyRegion", comment: "Body region"),
            NSLocalizedString("bodyPart", comment: "Body part"),
            NSLocalizedString("problematicAction", comment: "Problematic action"),
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
                    SymptomsDisplayRow(entry: entries[idx], colWidth: colWidth)
                    if idx < entries.indices.last! { Divider() }
                }
            }
        }
    }
}

// MARK: - Read-only Zeile
struct SymptomsDisplayRow: View {
    let entry: SymptomsStatusEntry
    let colWidth: CGFloat

    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {

            // Kopf: Seite + Re-Evaluation
            HStack {
                labelRow(NSLocalizedString("bodySide", comment: "Body side"), entry.side?.localized ?? "–")
                Spacer()
                BoolIndicatorWoSpacer(
                    value: entry.reevaluation,
                    label: NSLocalizedString("reevaluation", comment: "Re-evaluation")
                )
            }

            // Region & Teilbereich
            labelRow("bodyRegion", entry.bodyRegion?.region.localized() ?? "–")
            labelRow("bodyPart",   entry.bodyPart?.localized() ?? "–")
            
            // Problematische Aktion + Seit (Datum) in einer Zeile
            if let act = clean(entry.problematicAction),
               let since = entry.sinceDate {
               
                HStack(alignment: .firstTextBaseline, spacing: 16) {

                       // links: Problematische Aktion
                       labelRow("problematicAction", act)

                       // rechts: Seit (Datum)
                       inlineLabelRow(
                           "since",
                           since.formatted(dateOnly),
                           alignRight: true
                       )
                   }

            } else if let act = clean(entry.problematicAction) {
                labelRow("problematicAction", act)

            } else if let since = entry.sinceDate {
                labelRow("since", since.formatted(dateOnly))
            }

            // Schmerz (Struktur • Qualität • Stärke)
            painBlock

            // Notizen
            if let notes = clean(entry.symptomPains?.notes) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("notes", comment: "Notes"))
                            .frame(width: colWidth, alignment: .leading)
                        Text(notes)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Pain block
    @ViewBuilder
    private var painBlock: some View {
        let ps  = entry.symptomPains
        let str = ps?.painStructure?.localized() ?? "–"
        let qua = ps?.painQuality?.localized() ?? "–"
        let lvl = ps?.painLevel.map { "\($0.value)" } ?? "–"

        HStack {
            Text(NSLocalizedString("pain", comment: "Pain"))
                .frame(width: colWidth, alignment: .leading)
            Text("\(str) • \(qua) • \(lvl)")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func labelRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(NSLocalizedString(key, comment: ""))
                .frame(width: colWidth, alignment: .leading)
            Text(value).foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func inlineLabelRow(_ key: String, _ value: String, alignRight: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if !key.isEmpty {
                Text(NSLocalizedString(key, comment: ""))
            }

            Text(value)
                .multilineTextAlignment(alignRight ? .trailing : .leading)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: alignRight ? .trailing : .leading)
    }

    private func clean(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }

    private var dateOnly: Date.FormatStyle {
        .dateTime
            .year().month(.twoDigits).day(.twoDigits)
            .locale(Locale.current)
    }
}
