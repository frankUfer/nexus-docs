//
//  CSVTablePreview.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.04.25.
//

import SwiftUI

struct CSVTableView: View {
    let table: CSVTable
    let columnWidths: [CGFloat]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    
                    // Header
                    HStack(spacing: 0) {
                        ForEach(table.headers.indices, id: \.self) { col in
                            cell(text: table.headers[col], width: columnWidths[safe: col] ?? 100, isHeader: true)
                        }
                    }

                    // Rows
                    ForEach(table.rows.indices, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(table.rows[row].indices, id: \.self) { col in
                                let cellText = table.rows[row].indices.contains(col) ? table.rows[row][col] : ""
                                cell(text: cellText, width: columnWidths[safe: col] ?? 100, isHeader: false, rowIndex: row)
                            }
                        }
                    }
                }
                .padding()
            }

            // Schließen-Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .foregroundColor(.white)
                    .padding(.top, 50)
                    .padding(.leading, 20)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func cell(text: String, width: CGFloat, isHeader: Bool, rowIndex: Int = 0) -> some View {
        Text(text)
            .font(isHeader ? .headline : .body)
            .padding(8)
            .frame(width: width, alignment: .leading)
            .background(isHeader ? Color.gray.opacity(0.3) : rowIndex % 2 == 0 ? Color.white.opacity(0.05) : Color(.systemGray6).opacity(0.1))
            .foregroundColor(.white)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .border(Color.white.opacity(0.1), width: 0.5)
    }
}


