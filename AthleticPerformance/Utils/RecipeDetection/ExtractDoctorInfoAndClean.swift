//
//  extractDoctorInfoAndClean.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.04.25.
//

import Foundation

struct DoctorExtractionResult {
    var doctor: DiagnosisSource?
    var cleanedLines: [String]
}

func extractDoctorInfoAndClean(from lines: [String]) -> DoctorExtractionResult {
    var cleanedLines = lines
    var doctor = DiagnosisSource()

    var foundSpecialty: Specialty? = nil
    let specialties = AppGlobals.shared.specialties
    
    var nameSet = false
    var phoneSet = false
    var addressSet = false
    var citySet = false
    
    let mergedLines = lines.enumerated().map { ($0.offset, $0.element.trimmingCharacters(in: .whitespacesAndNewlines)) }

    for (index, line) in mergedLines {
        let lowercased = line.lowercased()
        
        // 1. Name (z. B. "Dr. med. X" oder "Prof X")
        if !nameSet, lowercased.contains("dr") || lowercased.contains("prof") {

            var name = line

            // Versuche, den Nachnamen aus nächster Zeile zu ergänzen (wenn die Zeile nicht wie Adresse/Telefon aussieht)
            if index + 1 < mergedLines.count {
                let nextLine = mergedLines[index + 1].1
                let wordCount = nextLine.split(separator: " ").count

                if wordCount == 1 &&
                    !isCompanyLine(nextLine) &&
                    !isPostalCityLine(nextLine) &&
                    !isStreetLine(nextLine) &&
                    !nextLine.lowercased().contains("tel") {
                    
                    name += " " + nextLine
                    cleanedLines[index + 1] = ""
                }
            }
            
            doctor.originName = name
            cleanedLines[index] = ""
            nameSet = true
            continue
        }
        
        // 2. Fachgebiet erkennen (auch über zwei Zeilen)
        if foundSpecialty == nil {
            if let specialty = specialties.first(where: { lowercased.contains($0.localizedName(locale: Locale(identifier: "de")).lowercased()) }) {
                foundSpecialty = specialty
                cleanedLines[index] = ""
                continue
            } else if index + 1 < mergedLines.count {
                let combined = lowercased + " " + mergedLines[index + 1].1.lowercased()
                if let specialty = specialties.first(where: { combined.contains($0.localizedName(locale: Locale(identifier: "de")).lowercased()) }) {
                    foundSpecialty = specialty
                    cleanedLines[index] = ""
                    cleanedLines[index + 1] = ""
                    continue
                }
            }
        }
        
        // 3. Suche nach Telefonnummern in Zeilen mit „Tel.“ oder „Telefon“
        if !phoneSet,
           (lowercased.contains("tel") || lowercased.contains("telefon")),
           !isCompanyLine(line),
           let phone = extractPhoneNumberFromLine(line) {
            doctor.phoneNumber = phone
            cleanedLines[index] = ""
            phoneSet = true
            continue
        }

        // 4. PLZ + Ort
        if !citySet, isPostalCityLine(line) {
            let (postal, city) = extractPostalCodeAndCity(from: line)
            doctor.postalCode = postal
            doctor.city = city
            cleanedLines[index] = ""
            citySet = true
            continue
        }

        // 5. Straße (wenn noch nicht gesetzt und Zeile endet auf PLZ oder beginnt nicht mit Zahl)
        if !addressSet, isStreetLine(line) {
            doctor.street = line
            cleanedLines[index] = ""
            addressSet = true
            continue
        }

        // 6. Kombinierte Zeile mit Straße + PLZ/Ort (z. B. "Musterstraße 1 - 12345 Stadt")
        if !addressSet || !citySet {
            if let (street, postal, city) = extractStreetPostalCityCombo(from: line) {
                if !addressSet {
                    doctor.street = street
                    addressSet = true
                }
                if !citySet {
                    doctor.postalCode = postal
                    doctor.city = city
                    citySet = true
                }
                cleanedLines[index] = ""
                continue
            }
        }
    }
    
    if !phoneSet {
        for (index, line) in lines.enumerated() {
            if isCompanyLine(line) { continue }
            if let phone = extractPhoneNumberFromLine(line) {
                doctor.phoneNumber = phone
                cleanedLines[index] = ""
                break
            }
        }
    }

    doctor.specialty = foundSpecialty

    let somethingFound = !doctor.originName.isEmpty ||
                         !doctor.phoneNumber.isEmpty ||
                         !doctor.street.isEmpty ||
                         !doctor.city.isEmpty

    return DoctorExtractionResult(
        doctor: somethingFound ? doctor : nil,
        cleanedLines: cleanedLines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    )
}

//// --- Hilfsfunktionen ---

private func isStreetLine(_ text: String) -> Bool {
    return text.range(of: #"^\D+\s+\d+[a-zA-Z]?$"#, options: .regularExpression) != nil
}

private func isPostalCityLine(_ text: String) -> Bool {
    return text.range(of: #"^\d{5}\s+\D+"#, options: .regularExpression) != nil
}

private func extractPostalCodeAndCity(from text: String) -> (String, String) {
    let parts = text.split(separator: " ", maxSplits: 1).map { String($0) }
    if parts.count == 2 {
        return (parts[0], parts[1])
    } else {
        return ("", text)
    }
}


private func extractStreetPostalCityCombo(from line: String) -> (street: String, postal: String, city: String)? {
    let pattern = #"(.+?)\s*[-,–]?\s*(\d{5})\s+([A-Za-zäöüÄÖÜß\s\-]+)$"#
    if let regex = try? NSRegularExpression(pattern: pattern) {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = regex.firstMatch(in: line, range: range),
           let streetRange = Range(match.range(at: 1), in: line),
           let postalRange = Range(match.range(at: 2), in: line),
           let cityRange = Range(match.range(at: 3), in: line) {
            let street = String(line[streetRange]).trimmingCharacters(in: .whitespaces)
            let postal = String(line[postalRange])
            let city = String(line[cityRange]).trimmingCharacters(in: .whitespaces)
            return (street, postal, city)
        }
    }
    return nil
}

private func isCompanyLine(_ line: String) -> Bool {
    let lower = line.lowercased()
    let blacklist = ["gmbh", "g.m.b.h", "gbr", "mvz", "praxis", "germany", "zentrum", "institut", "klinik"]
    return blacklist.contains(where: { lower.contains($0) })
}


private func extractPhoneNumberFromLine(_ line: String) -> String? {
    // Regex erlaubt z. B. "0 40 / 98 88 665", "040-988665", "(040) 988665"
    let pattern = #"(?<!\d)0[\s/\-\(\)]*\d(?:[\s/\-\(\)]*\d){6,}"#

    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    if let match = regex.firstMatch(in: line, range: range),
       let matchRange = Range(match.range, in: line) {
        let rawMatch = String(line[matchRange])
        
        // Entferne alle Nicht-Ziffern
        let digitsOnly = rawMatch.replacingOccurrences(of: #"\D"#, with: "", options: .regularExpression)
        return digitsOnly
    }
    
    return nil
}
