//
//  AssessmentStatusDisplayList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.10.25.
//

import SwiftUI

// MARK: - Display-Only List

struct AssessmentStatusDisplayList: View {
    let entries: [AssessmentStatusEntry]
    let titleKey: String
    let availableAssessments: [Assessments]

    var body: some View {
        let labelKeys = [
            NSLocalizedString("bodySide", comment: "Body side"),
            NSLocalizedString("assessment", comment: "Assessment"),
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
                    AssessmentStatusDisplayRow(
                        entry: entries[idx],
                        availableAssessments: availableAssessments,
                        colWidth: colWidth
                    )
                    if idx < entries.indices.last! { Divider() }
                }
            }
        }
    }
}

// MARK: - Read-only Zeile für ein einzelnes Assessment
struct AssessmentStatusDisplayRow: View {
    let entry: AssessmentStatusEntry
    let availableAssessments: [Assessments]
    let colWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Kopfzeile: Seite (links) + Re-evaluation (rechts)
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
            
            assessmentWithFindingRow

            // Freitext / Beschreibung (nur anzeigen wenn nicht leer)
            if let desc = clean(entry.description) {
                labelRow(
                    NSLocalizedString("notes", comment: "Notes"),
                    desc
                )
            }
        }
    }

    // MARK: - Assessment + Icon in einer Zeile
    @ViewBuilder
    private var assessmentWithFindingRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {

            // Linke Spalte: Label "Assessment"
            Text(NSLocalizedString("assessment", comment: "Assessment"))
                .frame(width: colWidth, alignment: .leading)

            // Rechte Spalte: Name des Assessments + Icon
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(assessmentName(for: entry.assessmentId) ?? "–")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                Image(systemName: entry.finding
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .foregroundColor(entry.finding ? .positiveCheck : .negativeCheck)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func assessmentName(for id: UUID) -> String? {
        availableAssessments.first(where: { $0.id == id })?.localized()
    }

    private func sideText(_ side: BodySides?) -> String {
        side?.localized ?? "–"
    }

    private func labelRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .frame(width: colWidth, alignment: .leading)
                .foregroundColor(.primary)

            Text(value)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    private func clean(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }
}
