//
//  OtherAnomalieStatusDisplayList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.10.25.
//

import SwiftUI

// MARK: - Read-only Liste (Anomalies)
struct OtherAnomalieStatusDisplayList: View {
    let entries: [OtherAnomalieStatusEntry]
    let titleKey: String
    let availableBodyRegions: [BodyRegionSelectionGroup]
    let availablePainQualities: [PainQualities]
    let availablePainStructures: [PainStructures]

    var body: some View {

        let labelKeys = [
            NSLocalizedString("bodySide", comment: "Body side"),
            NSLocalizedString("bodyRegion", comment: "Body region"),
            NSLocalizedString("bodyPart", comment: "Body part"),
            NSLocalizedString("anomaly", comment: "Anomaly"),
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
                    OtherAnomalieStatusDisplayRow(
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

// MARK: - Read-only Einzelzeile (Anomaly)
struct OtherAnomalieStatusDisplayRow: View {
    let entry: OtherAnomalieStatusEntry
    let colWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Kopfzeile:
            // links: Body side (mit Standard labelRow-Stil)
            // rechts: Reevaluation Toggle-Anzeige
            HStack {
                labelRow(
                    NSLocalizedString("bodySide", comment: "Body side"),
                    sideText(entry.side)
                )

                Spacer()

                BoolIndicatorWoSpacer(
                    value: entry.reevaluation,
                    label: NSLocalizedString("reevaluation", comment: "Re-evaluation")
                )
            }

            // Region / Körperteil
            labelRow(
                NSLocalizedString("bodyRegion", comment: "Body region"),
                regionName() ?? "–"
            )

            labelRow(
                NSLocalizedString("bodyPart", comment: "Body part"),
                partName() ?? "–"
            )

            // Anomalie-Text (optional)
            if let anomaly = nonEmpty(entry.anomaly) {
                labelRow(
                    NSLocalizedString("anomaly", comment: "Anomaly"),
                    anomaly
                )
            }

            // Schmerzblock (Struktur • Qualität • Level), einzeilig im Stil der anderen painBlocks
            if hasPainInfo(entry.anomalyPains) {
                painBlock
            }

            // Notizen (optional)
            if let notes = nonEmpty(entry.anomalyPains?.notes) {
                labelRow(
                    NSLocalizedString("notes", comment: "Notes"),
                    notes
                )
            }
        }
    }

    // MARK: - Pain Block (Struktur • Qualität • Stärke)
    @ViewBuilder
    private var painBlock: some View {
        let structure = entry.anomalyPains?.painStructure?.localized() ?? "–"
        let quality   = entry.anomalyPains?.painQuality?.localized() ?? "–"
        let level     = entry.anomalyPains?.painLevel.map { "\($0.value)" } ?? "–"

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(NSLocalizedString("pain", comment: "Pain"))
                .frame(width: colWidth, alignment: .leading)

            Text("\(structure) • \(quality) • \(level)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - labelRow (Key links, Value grau rechts)
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

    // MARK: - Helper Functions

    private func regionName() -> String? {
        entry.bodyRegion?.region.localized()
    }

    private func partName() -> String? {
        if let part = entry.bodyPart {
            return part.localized()
        }
        // Fallback: falls nur bodyRegion gesetzt ist und genau 1 selectedPart drin ist
        if let selected = entry.bodyRegion?.selectedParts.first {
            return selected.localized()
        }
        return nil
    }

    private func sideText(_ side: BodySides?) -> String {
        side?.localized ?? "–"
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard
            let t = s?.trimmingCharacters(in: .whitespacesAndNewlines),
            !t.isEmpty
        else { return nil }
        return t
    }

    /// Prüft, ob überhaupt sinnvolle Pain-Daten existieren
    private func hasPainInfo(_ pains: AnomalyPains?) -> Bool {
        guard let pains else { return false }

        if pains.painStructure != nil { return true }
        if pains.painQuality   != nil { return true }
        if pains.painLevel     != nil { return true }

        return false
    }
}
