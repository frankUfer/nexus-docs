//
//  extractDiagnosisInfo.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.04.25.
//

import Foundation

struct DiagnosisInfo {
    var text: String
    var diagnosisDate: Date?
}

struct DiagnosisExtractionResult {
    var diagnosis: DiagnosisInfo?
    var cleanedLines: [String]
}

func extractDiagnosisInfoAndClean(from lines: [String]) -> DiagnosisExtractionResult {
    var cleanedLines = lines
    var diagnosisLines: [String] = []
    var diagnosisDate: Date? = nil
    var isInsideDiagnosis = false
    var diagnosisStartIndex: Int? = nil
    var diagnosisEndIndex: Int? = nil
    
    for (index, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        if !isInsideDiagnosis {
            if lowercased.contains("d:") || lowercased.contains("dg.") || lowercased.contains("diagnose") || lowercased.contains("diag."){
                isInsideDiagnosis = true
                diagnosisStartIndex = index
                diagnosisLines.append(trimmed)
            }
        } else {
            if isDiagnosisEnd(line: lowercased) {
                diagnosisEndIndex = index - 1
                break
            }
            diagnosisLines.append(trimmed)
        }
    }

    // Falls ein Block gesammelt wurde
    if let start = diagnosisStartIndex {
        let end = diagnosisEndIndex ?? (start + diagnosisLines.count - 1)
        cleanedLines.removeSubrange(start...end)

        // Diagnose-Text zusammenfassen
        let rawText = diagnosisLines.joined(separator: " ")

        // Datum aus dem Textteil extrahieren
        var finalText = rawText
        if let (dateStr, date) = findDiagnosisDate(in: rawText) {
            diagnosisDate = date
            finalText = rawText.replacingOccurrences(of: dateStr, with: "")
        } else {
            // 🔁 Fallback: Datum global im Rest suchen
            for line in cleanedLines {
                if let (_, date) = findDiagnosisDate(in: line) {
                    diagnosisDate = date
                    break
                }
            }
        }

        // Bereinigung von Diagnose-Beginntexten
        let cleanedText = finalText
            .replacingOccurrences(of: #"(?i)diagnosen:?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)diagnose:?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)diag\.?:?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)dg\.?:?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)d\.?:?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return DiagnosisExtractionResult(
            diagnosis: DiagnosisInfo(text: cleanedText, diagnosisDate: diagnosisDate),
            cleanedLines: cleanedLines
        )
    }

    // ❌ Kein Diagnose-Block → nur globales Datum prüfen
    let fallbackDate: Date? = {
        for line in lines {
            if let (_, date) = findDiagnosisDate(in: line) {
                return date
            }
        }
        return nil
    }()

    return DiagnosisExtractionResult(
        diagnosis: fallbackDate != nil ? DiagnosisInfo(text: "", diagnosisDate: fallbackDate) : nil,
        cleanedLines: cleanedLines
    )
}

private func isDiagnosisEnd(line: String) -> Bool {
    if line.isEmpty { return true }
    if line == "* *" || line.allSatisfy({ !$0.isLetter && !$0.isNumber }) { return true }

    let stopPhrases = ["tel", "fax", "gmbh", "praxis", "dr.", "mvz", "arzt", "aerztin", "medizinisches versorgungszentrum", "im auftrag"]
    if stopPhrases.contains(where: { line.contains($0) }) {
        return true
    }

    if line.hasPrefix("für") || line.hasPrefix("wegen") { return true }

    return false
}

private func findDiagnosisDate(in text: String) -> (String, Date)? {
    let formats = ["dd.MM.yy", "dd.MM.yyyy"]
    let currentYear = Calendar.current.component(.year, from: Date())

    for format in formats {
        let pattern = format == "dd.MM.yy" ? #"(\d{2}\.\d{2}\.\d{2})"# : #"(\d{2}\.\d{2}\.\d{4})"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            for match in matches {
                if let dateRange = Range(match.range(at: 1), in: text) {
                    let dateString = String(text[dateRange])
                    
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "de_DE")
                    formatter.dateFormat = format
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)

                    if let date = formatter.date(from: dateString) {
                        let calendar = Calendar.current
                        let year = calendar.component(.year, from: date)
                        
                        let isRecentYear = (year == currentYear || year == currentYear - 1)
                        let isPastOrToday = date <= Date()
                        
                        if isRecentYear && isPastOrToday {
                            return (dateString, date)
                        }
                    }
                }
            }
        }
    }

    return nil
}
