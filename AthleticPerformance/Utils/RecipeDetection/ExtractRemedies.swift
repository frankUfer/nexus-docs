//
//  extractRemedies.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.04.25.
//

import Foundation

struct Remedy {
    var name: String
    var quantity: String
}

struct RemedyExtractionResult {
    var remedies: [Remedy]
    var cleanedLines: [String]
}

func extractRemedies(from section: [String]) -> RemedyExtractionResult {
    guard !section.isEmpty else {
        return RemedyExtractionResult(remedies: [], cleanedLines: [])
    }

    var remedies: [Remedy] = []
    let knownServices = AppGlobals.shared.treatmentServices

    // ✅ 1. Alle x-Mengen + Services extrahieren (auch über 2 Zeilen)
    let (matches, cleanedLinesAfterXParsing) = parseQuantitiesAndServicesFromSection(section)
    var cleanedLines = cleanedLinesAfterXParsing

    // ✅ 2. Erkannte Mengen + Services verarbeiten
    for (quantity, serviceName) in matches {
        if let matchedService = knownServices.first(where: { service in
            service.de.lowercased().contains(serviceName) || serviceName.contains(service.de.lowercased()) ||
            service.id.lowercased() == serviceName
        }) {
            let remedy = Remedy(name: matchedService.de, quantity: quantity)
            if !remedies.contains(where: { $0.name == remedy.name && $0.quantity == remedy.quantity }) {
                remedies.append(remedy)
            }
        } else {
            let remedy = Remedy(name: serviceName, quantity: quantity)
            if !remedies.contains(where: { $0.name == remedy.name && $0.quantity == remedy.quantity }) {
                remedies.append(remedy)
            }
        }
    }
    
    // ✅ 3. Übrige Zeilen auf einzelne Services prüfen (Fallback)
    for (index, line) in cleanedLines.enumerated() {
        let lowercasedLine = line.lowercased()

        if let matchedService = knownServices.first(where: { service in
            lowercasedLine.contains(service.de.lowercased()) ||
            lineContainsExactServiceId(lowercasedLine, id: service.id.lowercased())
        }) {
            let remedy = Remedy(name: matchedService.de, quantity: "1")
            if !remedies.contains(where: { $0.name == remedy.name && $0.quantity == remedy.quantity }) {
                remedies.append(remedy)
            }
            cleanedLines[index] = removePartialMatch(matchText: matchedService.de, from: line)
        }
    }

    return RemedyExtractionResult(remedies: remedies, cleanedLines: cleanedLines)
}

func parseQuantitiesAndServicesFromSection(_ lines: [String]) -> (matches: [(quantity: String, serviceName: String)], cleanedLines: [String]) {
    var results: [(quantity: String, serviceName: String)] = []
    var cleanedLines = lines
    var i = 0

    let knownServices = AppGlobals.shared.treatmentServices

    while i < cleanedLines.count {
        let line = cleanedLines[i]

        // 1. Normaler 1-Zeilen-Parser
        let pairs = extractAllQuantityServicePairs(from: line)
        if !pairs.isEmpty {
            var foundValid = false

            for (quantity, rawService) in pairs {
                let serviceParts = rawService
                    .components(separatedBy: CharacterSet(charactersIn: "/,;+"))
                    .flatMap { $0.components(separatedBy: " und ") }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                for part in serviceParts where !part.isEmpty {
                    foundValid = true
                    let matchedServiceName = knownServices.first(where: { service in
                        let lcPart = part.lowercased()
                        return service.de.lowercased().contains(lcPart)
                            || lcPart.contains(service.de.lowercased())
                            || service.id.lowercased() == lcPart
                    })?.de ?? part

                    results.append((quantity, matchedServiceName))
                }
            }

            if foundValid {
                cleanedLines[i] = ""
                i += 1
                continue
            }
        }

        // 2. Fall: "15" + "x Manuelle Therapie"
        if i + 1 < cleanedLines.count,
           line.range(of: #"^\d+$"#, options: .regularExpression) != nil {

            let nextLine = cleanedLines[i + 1].trimmingCharacters(in: .whitespaces)
            
            if nextLine.lowercased().hasPrefix("x ") || nextLine.lowercased().hasPrefix("x ") {  // normales oder geschütztes Leerzeichen
                let quantity = line.trimmingCharacters(in: .whitespaces)
                let rawService = nextLine.dropFirst(2).trimmingCharacters(in: .whitespaces)  // alles nach "x "

                let matchedServiceName = knownServices.first(where: { service in
                    let lc = rawService.lowercased()
                    return service.de.lowercased().contains(lc)
                        || lc.contains(service.de.lowercased())
                        || service.id.lowercased() == lc
                })?.de ?? rawService

                results.append((quantity, matchedServiceName))
                cleanedLines[i] = ""
                cleanedLines[i + 1] = ""
                i += 2
                continue
            }
        }

        // 3. Fall: "15 x" + "KG"
        let normalized = line.lowercased().replacingOccurrences(of: " ", with: " ") // ersetzt geschütztes Leerzeichen
        let trimmed = normalized.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasSuffix(" x") || trimmed.hasSuffix("x")),
           i + 1 < cleanedLines.count {

            let components = trimmed.split(separator: "x", maxSplits: 1)
            let quantity = components.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let nextLine = cleanedLines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)

            if !quantity.isEmpty, !nextLine.isEmpty {
                let matchedServiceName = knownServices.first(where: { service in
                    let lc = nextLine.lowercased()
                    return service.de.lowercased().contains(lc)
                        || lc.contains(service.de.lowercased())
                        || service.id.lowercased() == lc
                })?.de ?? nextLine

                results.append((quantity, matchedServiceName))
                cleanedLines[i] = ""
                cleanedLines[i + 1] = ""
                i += 2
                continue
            }
        }

        i += 1
    }

    return (results, cleanedLines)
}


// Entfernt den übereinstimmenden Text
private func removePartialMatch(matchText: String, from line: String) -> String {
    let pattern = NSRegularExpression.escapedPattern(for: matchText)
    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let cleaned = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
        return cleaned
    }
    return line
}

func lineContainsExactServiceId(_ line: String, id: String) -> Bool {
    let pattern = #"(?i)\b\#(NSRegularExpression.escapedPattern(for: id))\b"#
    return line.range(of: pattern, options: .regularExpression) != nil
}


private func extractAllQuantityServicePairs(from line: String) -> [(String, String)] {
    // Erkennt mehrere 10x … Blöcke in EINER Zeile
    let pattern = #"(?i)(\d+)\s*[xX]\s*(.*?)(?=(?:\d+\s*[xX])|\Z)"#

    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    let nsLine = line as NSString
    let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

    return matches.compactMap { match in
        guard match.numberOfRanges == 3 else { return nil }
        let quantity = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let service = nsLine.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        return (quantity, service)
    }
}
