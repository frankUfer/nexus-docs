//
//  MarkupSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 07.07.25.
//

import Foundation
import SwiftUI

struct MarkupSpec {
    let pattern: MarkupPattern   // Was ist es? h1, h2, bullet, bold, ...
    let fontName: String
    let fontSize: CGFloat
    let isBold: Bool
    let isItalic: Bool
    let color: UIColor
    
    // Nur für Bullets relevant:
    let bulletSymbol: String?    // z. B. •, -, +
    let indent: CGFloat          // Einrückung der gesamten Zeile
    let bulletSpacing: CGFloat   // Abstand Bullet → Text
}

enum MarkupPattern {
    case h1       // # Überschrift
    case h2       // ## Überschrift
    case bullet   // * Bullet
    case bold     // **text** (nur inline, handled separat)
    case italic   // *text*  (nur inline, handled separat)
    case normal   // Absatz ohne explizites Markup
    case pageBreak

    static func detect(for line: String) -> MarkupPattern {
        if line.hasPrefix("# ") {
            return .h1
        } else if line.hasPrefix("## ") {
            return .h2
        } else if line.hasPrefix("* ") {
            return .bullet
        } else if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---PAGEBREAK---" {
            return .pageBreak
        } else {
            return .normal
        }
    }
}

let defaultMarkupSpecs: [MarkupPattern: MarkupSpec] = [
    .h1: MarkupSpec(
        pattern: .h1,
        fontName: "HelveticaNeue-Bold",
        fontSize: 14,
        isBold: true,
        isItalic: false,
        color: .black,
        bulletSymbol: nil,
        indent: 0,
        bulletSpacing: 0
    ),
    .h2: MarkupSpec(
        pattern: .h2,
        fontName: "HelveticaNeue-Bold",
        fontSize: 12,
        isBold: true,
        isItalic: false,
        color: .darkGray,
        bulletSymbol: nil,
        indent: 0,
        bulletSpacing: 0
    ),
    .bullet: MarkupSpec(
        pattern: .bullet,
        fontName: "HelveticaNeue",
        fontSize: 12,
        isBold: false,
        isItalic: false,
        color: .black,
        bulletSymbol: "•",
        indent: 20,
        bulletSpacing: 8
    ),
    .bold: MarkupSpec(
        pattern: .bold,
        fontName: "HelveticaNeue-Bold",
        fontSize: 12,
        isBold: true,
        isItalic: false,
        color: .black,
        bulletSymbol: nil,
        indent: 0,
        bulletSpacing: 0
    ),
    .italic: MarkupSpec(
        pattern: .italic,
        fontName: "HelveticaNeue-Italic",
        fontSize: 12,
        isBold: false,
        isItalic: true,
        color: .black,
        bulletSymbol: nil,
        indent: 0,
        bulletSpacing: 0
    ),
    .normal: MarkupSpec(
        pattern: .normal,
        fontName: "HelveticaNeue",
        fontSize: 12,
        isBold: false,
        isItalic: false,
        color: .black,
        bulletSymbol: nil,
        indent: 0,
        bulletSpacing: 0
    )
]
