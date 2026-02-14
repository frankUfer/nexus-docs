//
//  CSVPreviewMiniView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.04.25.
//

import SwiftUI

struct CSVPreviewMiniView: View {
    let table: CSVTable
    let columnWidths: [CGFloat]
    let fontSize: CGFloat
    
    private let maxColumns = 5
    private let maxRows = 25
    
    var body: some View {
         VStack(spacing: 0) {
             // Header
             HStack(spacing: 0) {
                 ForEach(0..<min(maxColumns, table.headers.count), id: \.self) { col in
                     let headerText = table.headers[col]
                     cell(text: headerText, width: columnWidths[safe: col] ?? 100, isHeader: true)
                 }
             }

             // Rows
             ForEach(0..<min(maxRows - 1, table.rows.count), id: \.self) { row in
                 let cells = table.rows[row]
                 
                 HStack(spacing: 0) {
                     ForEach(0..<min(maxColumns, cells.count), id: \.self) { col in
                         let text = cells.indices.contains(col) ? cells[col] : ""
                         cell(text: text, width: columnWidths[safe: col] ?? 100, isHeader: false, rowIndex: row)
                     }
                 }
             }
         }
        .padding()
        .background(Color.black)
        .cornerRadius(4)
        .shadow(radius: 0.5)
    }

    @ViewBuilder
        private func cell(text: String, width: CGFloat, isHeader: Bool, rowIndex: Int = 0) -> some View {
            Text(text.isEmpty ? " " : text)
                .font(.system(size: fontSize, weight: isHeader ? .bold : .regular, design: .monospaced))
                .padding(4)
                .frame(width: width, alignment: .leading)
                .background(isHeader ? Color.gray.opacity(0.3) : rowIndex % 2 == 0 ? Color.white.opacity(0.05) : Color(.systemGray6).opacity(0.1))
                .foregroundColor(.white)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .border(Color.white.opacity(0.1), width: 0.5)
        }
}
