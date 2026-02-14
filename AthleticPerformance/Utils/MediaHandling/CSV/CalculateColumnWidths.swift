//
//  calculateColumnWidths.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.04.25.
//

import Foundation
import UIKit

func calculateColumnWidths(for table: CSVTable, fontSize: CGFloat = 16) -> [CGFloat] {
    let headerFont = UIFont.boldSystemFont(ofSize: fontSize)
    let cellFont = UIFont.systemFont(ofSize: fontSize)
    let colCount = table.headers.count
    var maxWidths = Array(repeating: 0.0, count: colCount)

    // Header mit Bold-Font
    for (i, header) in table.headers.enumerated() {
        maxWidths[i] = max(maxWidths[i], header.width(usingFont: headerFont))
    }

    // Datenzeilen mit normalem Font
    for row in table.rows {
        for (i, cell) in row.enumerated() {
            if i < maxWidths.count {
                let content = cell.isEmpty ? " " : cell
                maxWidths[i] = max(maxWidths[i], content.width(usingFont: cellFont))
            }
        }
    }

    // +24 für Padding
    return maxWidths.map { ceil($0) + 24 }
}
