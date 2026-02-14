//
//  CSVTable.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.04.25.
//

import Foundation

struct CSVTable {
    var headers: [String]
    var rows: [[String]]

    init?(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let allRows = CSVTable.parseCSV(from: content)

        guard !allRows.isEmpty else { return nil }

        self.headers = allRows[0]
        self.rows = Array(allRows.dropFirst())
    }

    /// Erkennung von `,` oder `;` und Parsen in Zeilen + Spalten
    private static func parseCSV(from string: String) -> [[String]] {
        let delimiter: Character = string.contains(";") ? ";" : ","
        return string
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map {
                $0.split(separator: delimiter, omittingEmptySubsequences: false)
                  .map { String($0) }
            }
    }
}
