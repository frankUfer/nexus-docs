//
//  TableCellContent.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import SwiftUI

struct TableCellContent {
    let text: String
    let isBold: Bool
    let isItalic: Bool
    let fontSize: CGFloat?  // Optional: Überschreiben des Layout-Defaults
    let color: CGColor?     // Optional: Farbe

    init(text: String, isBold: Bool = false, isItalic: Bool = false, fontSize: CGFloat? = nil, color: CGColor? = nil) {
        self.text = text
        self.isBold = isBold
        self.isItalic = isItalic
        self.fontSize = fontSize
        self.color = color
    }
}
