//
//  CalculateColumnWidth.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 25.10.25.
//

import SwiftUI
import UIKit

/// Berechnet eine sinnvolle Spaltenbreite (colWidth) auf Basis der längsten Labeltexte.
/// - Parameters:
///   - keys: Array von Label-Strings (lokalisierte Schlüssel, inkl. oder exkl. „:“ – egal)
///   - font: Die zu verwendende Schrift (Standard: `.body`)
///   - padding: Zusätzlicher Puffer in Punkten (Standard: 8)
///   - maxWidth: Maximale erlaubte Breite (Standard: 200)
///   - minWidth: Minimale erlaubte Breite (Standard: 80)
/// - Returns: Empfohlene Spaltenbreite in Punkten.
func calculateColumnWidth(
    for keys: [String],
    font: UIFont = .preferredFont(forTextStyle: .body),
    padding: CGFloat = 8,
    maxWidth: CGFloat = 200,
    minWidth: CGFloat = 80
) -> CGFloat {
    guard !keys.isEmpty else { return minWidth }

    let maxLabelWidth = keys
        .map { measuredTextWidth($0 + ":", font: font) }
        .max() ?? minWidth

    return min(maxLabelWidth + padding, maxWidth)
}

/// Hilfsfunktion, um die Textbreite eines Strings für eine bestimmte Schrift zu messen.
private func measuredTextWidth(_ text: String, font: UIFont) -> CGFloat {
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    return (text as NSString).size(withAttributes: attributes).width
}
