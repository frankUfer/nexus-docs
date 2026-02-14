//
//  PatientOCRMatcher.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.04.25.
//

import Foundation

struct PatientMatchResult {
    var matchPercentage: Int
    var cleanedOCRLines: [String]
}

class PatientOCRMatcher {
    
    /// Vergleicht Patientendaten mit OCR-Textzeilen und berechnet eine prozentuale Übereinstimmung  
    func match(patient: Patient, in ocrLines: [String]) -> PatientMatchResult {
        var totalSimilarity: Double = 0
        var fieldCount: Double = 0
        
        // Arbeitskopie für Bereinigung
        var lines = ocrLines.map { removeTitles($0) }
        
        // --- FULLNAME versuchen ---
        let fullName = "\(patient.firstname) \(patient.lastname)".trimmingCharacters(in: .whitespaces)
        let fullNameMatched = bestFieldMatch(fullName, in: &lines, exact: true)
        
        if fullNameMatched > 50 {
            totalSimilarity += fullNameMatched
            fieldCount += 1
        } else {
            totalSimilarity += fullNameMatched
            fieldCount += 1
        }
              
        _ = removeNamePair(firstname: patient.firstname, lastname: patient.lastname, from: &lines)
        
        // --- Adresse ---
        if let address = patient.addresses.first?.value {
            totalSimilarity += bestFieldMatch(address.street, in: &lines)
            fieldCount += 1

            let postalAndCity = "\(address.postalCode) \(address.city)"
            totalSimilarity += bestFieldMatch(postalAndCity, in: &lines)
            fieldCount += 1
        }
        
        // --- Geburtsdatum ---
        let shortDate = formatDate(patient.birthdate, format: "dd.MM.yy")
        let fullDate = formatDate(patient.birthdate, format: "dd.MM.yyyy")

        let containsShortDate = lines.contains { $0.contains(shortDate) }
        let containsFullDate = lines.contains { $0.contains(fullDate) }

        if containsShortDate || containsFullDate {
            let shortDateExactMatch = removeExactMatch(shortDate, from: &lines)
            let fullDateExactMatch = removeExactMatch(fullDate, from: &lines)

            let birthdateMatched = shortDateExactMatch || fullDateExactMatch

            if birthdateMatched {
                totalSimilarity += 100
                fieldCount += 1
            } else {
                totalSimilarity = 0
            }
        }

        let matchPercentage = Int((totalSimilarity / fieldCount).rounded())

        return PatientMatchResult(
            matchPercentage: matchPercentage,
            cleanedOCRLines: lines
        )
    }
    
    /// Entfernt exakte Übereinstimmung aus einer Zeile und gibt true zurück, wenn gefunden
    private func removeExactMatch(_ text: String, from lines: inout [String]) -> Bool {
        let normalizedText = normalize(text)

        for i in lines.indices {
            let normalizedLine = normalize(lines[i])

            if normalizedLine.contains(normalizedText) {
                lines[i] = lines[i].replacingOccurrences(of: text, with: "", options: .caseInsensitive)
                return true
            }
        }

        return false
    }
    
    
    private func removePartialMatchFuzzy(_ target: String, from line: String) -> String {
        let normTarget = normalize(target)

        let words = line.components(separatedBy: .whitespacesAndNewlines)
        var bestMatch: String?
        var bestSimilarity: Double = 0.0

        // Alle Wortgruppen (2er, 3er, 4er...) durchprobieren
        for length in (1...min(4, words.count)).reversed() {
            for i in 0...(words.count - length) {
                let fragment = words[i..<i+length].joined(separator: " ")
                let similarity = similarityPercentage(normTarget, normalize(fragment))
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestMatch = fragment
                }
            }
        }

        if let match = bestMatch, bestSimilarity > 60 {
            let escaped = NSRegularExpression.escapedPattern(for: match)
            if let regex = try? NSRegularExpression(pattern: escaped, options: [.caseInsensitive]) {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                let cleaned = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
                return cleaned
            }
        } 

        return line
    }
    
    // MARK: - Einzelne Felder vergleichen und ggf. löschen
    
    private func bestFieldMatch(_ text: String, in lines: inout [String]) -> Double {
        guard !text.isEmpty else { return 0.0 }
        
        var bestSimilarity: Double = 0
        var bestLineIndex: Int? = nil
        
        let normalizedText = normalize(text)
        
        for (index, line) in lines.enumerated() {
            let normalizedLine = normalize(line)
            let similarity = similarityPercentage(normalizedText, normalizedLine)
            
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestLineIndex = index
            }
        }
        
        // Text sofort aus der Zeile entfernen, wenn brauchbare Ähnlichkeit gefunden
        if let index = bestLineIndex, bestSimilarity > 50 {
            lines[index] = removePartialMatchFuzzy(text, from: lines[index])
        }
        
        return bestSimilarity
    }
    
    // MARK: - Hilfsmethoden
        
    private func normalize(_ text: String) -> String {
        var result = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Umlaute umwandeln
        result = result.replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
        
        // Kürzel auflösen
        let replacements = [
            "straße": "str",
            "str.": "str",
            "strasse": "str",
            "platz": "pl",
            "pl.": "pl",
            "weg": "wg",
            "allee": "al",
            "an der ": "",
            "am ": "",
            "zu der ": "",
        ]

        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }

        // Entferne Sonderzeichen und mehrfaches Leerzeichen
        result = result.replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return result
    }
    
    private func similarityPercentage(_ text1: String, _ text2: String) -> Double {
        let distance = levenshteinDistance(text1, text2)
        let maxLength = max(text1.count, text2.count)
        
        guard maxLength > 0 else { return 100.0 } 
        
        let similarity = (1.0 - (Double(distance) / Double(maxLength))) * 100
        return max(0, similarity)
    }
    
    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsArray = Array(lhs)
        let rhsArray = Array(rhs)

        if lhsArray.isEmpty { return rhsArray.count }
        if rhsArray.isEmpty { return lhsArray.count }
        
        var distance = [[Int]](repeating: [Int](repeating: 0, count: rhsArray.count + 1), count: lhsArray.count + 1)

        for i in 0...lhsArray.count { distance[i][0] = i }
        for j in 0...rhsArray.count { distance[0][j] = j }

        for i in 1...lhsArray.count {
            for j in 1...rhsArray.count {
                if lhsArray[i-1] == rhsArray[j-1] {
                    distance[i][j] = distance[i-1][j-1]
                } else {
                    distance[i][j] = min(
                        distance[i-1][j] + 1,
                        distance[i][j-1] + 1,
                        distance[i-1][j-1] + 1
                    )
                }
            }
        }

        return distance[lhsArray.count][rhsArray.count]
    }
    
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    private func removePartialMatch(_ text: String, from line: String) -> String {
        let pattern = NSRegularExpression.escapedPattern(for: text)
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            return regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
        }
        return line
    }
    
    private func removeTitles(_ line: String) -> String {
        let titles = ["Herr", "Frau", "Dr.", "Prof."]
        var result = line
        for title in titles {
            result = result.replacingOccurrences(of: "\\b\(title)\\b", with: "", options: [.caseInsensitive, .regularExpression])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func bestFieldMatch(_ text: String, in lines: inout [String], exact: Bool = false) -> Double {
        guard !text.isEmpty else { return 0.0 }
        
        var bestSimilarity: Double = 0
        var bestLineIndex: Int? = nil
        
        let normalizedText = normalize(text)
        
        for (index, line) in lines.enumerated() {
            let normalizedLine = normalize(line)
            let similarity = similarityPercentage(normalizedText, normalizedLine)
            
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestLineIndex = index
            }
        }
        
        if let _ = bestLineIndex, bestSimilarity > 50 {
            if exact {
                _ = removeSubstring(text, from: &lines)
            } else {
                lines[bestLineIndex!] = removePartialMatchFuzzy(text, from: lines[bestLineIndex!])
            }
        }
        
        return bestSimilarity
    }
    
    /// Entfernt exakten Substring aus allen Zeilen (nicht nur komplette Zeilen vergleichen!)
    private func removeSubstring(_ target: String, from lines: inout [String]) -> Bool {
        let normTarget = normalize(target)
        var found = false

        for i in lines.indices {
            let original = lines[i]
            let normLine = normalize(original)

            if normLine.contains(normTarget) {
                // Versuche exakten Substring im Original zu finden
                if original.range(of: target, options: .caseInsensitive) != nil {
                    lines[i] = original.replacingOccurrences(of: target, with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                    found = true
                    continue
                }

                // Wenn das nicht klappt: Baue Regex-Match für Wörter der normalisierten Version
                let targetWords = target.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                for word in targetWords {
                    let escaped = NSRegularExpression.escapedPattern(for: word)
                    if let regex = try? NSRegularExpression(pattern: escaped, options: [.caseInsensitive]) {
                        let range = NSRange(original.startIndex..<original.endIndex, in: original)
                        let cleaned = regex.stringByReplacingMatches(in: original, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
                        lines[i] = cleaned
                        found = true
                    }
                }
            }
        }

        return found
    }
    
    private func removeNamePair(firstname: String, lastname: String, from lines: inout [String]) -> Bool {
        let normFirst = normalize(firstname)
        let normLast = normalize(lastname)
        var found = false

        for i in lines.indices {
            let originalLine = lines[i]
            let normalizedLine = normalize(originalLine)

            // Beide Namen müssen vorkommen
            guard normalizedLine.contains(normFirst), normalizedLine.contains(normLast) else { continue }

            // Positionen im Originaltext ermitteln
            let words = originalLine.components(separatedBy: .whitespaces)
            var firstIndex: Int? = nil
            var lastIndex: Int? = nil

            for (idx, word) in words.enumerated() {
                let normWord = normalize(word)
                if firstIndex == nil, normWord == normFirst {
                    firstIndex = idx
                } else if lastIndex == nil, normWord == normLast {
                    lastIndex = idx
                }
            }

            if let fi = firstIndex, let li = lastIndex, abs(fi - li) <= 2 {
                // Sie stehen nahe beieinander → beide löschen
                var cleanedWords = words
                cleanedWords[fi] = ""
                cleanedWords[li] = ""

                lines[i] = cleanedWords.joined(separator: " ").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                found = true
            }
        }

        return found
    }
}
