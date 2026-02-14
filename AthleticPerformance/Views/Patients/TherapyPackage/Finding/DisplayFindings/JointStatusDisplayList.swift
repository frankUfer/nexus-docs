//
//  JointStatusDisplayList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.10.25.
//

import SwiftUI

// MARK: - Read-only Liste (Joints)
struct JointStatusDisplayList: View {
    let entries: [JointStatusEntry]
    let titleKey: String
    let availableMovements: [JointMovementPattern]
    let availablePainQualities: [PainQualities]
    let availableEndFeelings: [EndFeelings]

    var body: some View {
        let labelKeys = [
            NSLocalizedString("bodySide", comment: "Body side"),
            NSLocalizedString("joint", comment: "Joint"),
            NSLocalizedString("movement", comment: "Movement"),
            NSLocalizedString("pain", comment: "Pain"),
            NSLocalizedString("endFeel", comment: "End feel"),
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
                    JointStatusDisplayRow(
                        entry: entries[idx],
                        colWidth: colWidth
                    )
                    if idx < entries.indices.last! { Divider() }
                }
            }
        }
    }
}

// MARK: - Read-only Zeile (Joint)
struct JointStatusDisplayRow: View {
    let entry: JointStatusEntry
    let colWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Kopf: Seite links, Re-Evaluation rechts (wie Symptoms)
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

            // Gelenk
            labelRow(
                NSLocalizedString("joint", comment: "Joint"),
                entry.joint.localized()
            )

            // Bewegung
            movementBlock

            // Schmerzblock (Qualität • Stärke), wie bei Symptoms painBlock
            painBlock

            // Endgefühl
            labelRow(
                NSLocalizedString("endFeel", comment: "End feel"),
                entry.endFeeling?.localized() ?? "–"
            )

            // Notizen
            if let notes = clean(entry.notes) {
                labelRow(
                    NSLocalizedString("notes", comment: "Notes"),
                    notes
                )
            }
        }
    }

    // MARK: - Pain block (Qualität • Level)
    @ViewBuilder
    private var painBlock: some View {
        let pq  = entry.painQuality?.localized() ?? "–"
        let lvl = entry.painLevel.map { "\($0.value)" } ?? "–"

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(NSLocalizedString("pain", comment: "Pain"))
                .frame(width: colWidth, alignment: .leading)

            Text("\(pq) • \(lvl)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var movementBlock: some View {
        // Bewegung
        let movementText = entry.movement.localized()

        // Wert (mit Einheit/Geräte-Logik)
        let valueText = valueString()

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Linke Spalte: "movement" (feste Spaltenbreite wie bei painBlock)
            Text(NSLocalizedString("movement", comment: "Movement"))
                .frame(width: colWidth, alignment: .leading)

            // Rechte Spalte: "Bewegung • Wert"
            Text("\(movementText) • \(valueText)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

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

    /// Baut den darzustellenden Wert für "value" (z. B. Bewegungsumfang ° oder Ja/Nein)
    private func valueString() -> String {
        let unit = entry.movement.unit ?? ""
        switch entry.movement.inputType {
        case .slider:
            if case let .number(v) = entry.value {
                if unit.isEmpty {
                    return String(format: "%.0f", v)
                } else {
                    return String(format: "%.0f %@", v, unit)
                }
            } else {
                return "–"
            }

        case .toggle:
            if case let .boolean(b) = entry.value {
                return b
                    ? NSLocalizedString("yes", comment: "Yes")
                    : NSLocalizedString("no", comment: "No")
            } else {
                return "–"
            }

        default:
            return "–"
        }
    }

    /// Trim helper wie bei Symptoms
    private func clean(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }
}
