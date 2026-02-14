//
//  TextPlaceholderReplacer.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import Foundation
import UIKit

struct TextPlaceholderReplacer {

    /// ➜ Nur Platzhalter ersetzen, ergibt einen sauberen NSAttributedString
    static func generateContractText(
        template: NSAttributedString,
        practice: PracticeInfo,
        patient: Patient,
        date: Date,
        therapy: Therapy? = nil
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: template)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: date)

        let practiceAddress = practice.address
        let place = practice.address.city
        let patientAddress = patient.addresses.first?.value

        var replacements: [String: String] = [
            "[[PRACTICE_NAME]]": practice.name,
            "[[PRACTICE_STREET]]": practiceAddress.street,
            "[[PRACTICE_POSTALCODE]]": practiceAddress.postalCode,
            "[[PRACTICE_CITY]]": practiceAddress.city,
            "[[PRACTICE_PHONE]]": practice.phone,
            "[[PRACTICE_EMAIL]]": practice.email,

            "[[TITLE]]": patient.title.rawValue.isEmpty ? "" : "\(patient.title.rawValue) ",
            "[[FIRSTNAME]]": patient.firstname,
            "[[LASTNAME]]": patient.lastname,
            "[[STREET]]": patientAddress?.street ?? "",
            "[[POSTALCODE]]": patientAddress?.postalCode ?? "",
            "[[CITY]]": patientAddress?.city ?? "",

            "[[PLACE_DATE]]": "\(place), \(dateString)"
        ]

        // ✳️ Zusätzliche Platzhalter, wenn Therapie verfügbar
        if let therapy = therapy {
            let sessionsTable = buildSessionsTableText(
                sessions: therapy.therapyPlans.flatMap { $0.treatmentSessions },
                spec: defaultSessionTableSpec
            )

            let remediesTable = buildRemediesTableText(
                remedies: aggregateRemedies(from: therapy),
                spec: defaultRemedyTableSpec
            )

            replace(placeholder: "[[SESSIONS_OF_THERAPY]]", with: sessionsTable, in: mutable)
            replace(placeholder: "[[REMEDIES_OF_THERAPY]]", with: remediesTable, in: mutable)

            replacements["[[GOAL_OF_THERAPY]]"] = therapy.goals
            replacements["[[RISKS_OF_THERAPY]]"] = therapy.risks.isEmpty ? "" : "\n\(NSLocalizedString("additionalRisks", comment: "Additional risk information"))\n\(therapy.risks)"
            replacements["[[INVOICING_TERMS]]"] = therapy.billingPeriod.localizedDescription
        }

        for (placeholder, value) in replacements {
            replace(placeholder: placeholder, with: NSAttributedString(string: value), in: mutable)
        }

        return mutable
    }

    /// ➜ Platzhalter ersetzen
    private static func replace(
        placeholder: String,
        with value: NSAttributedString,
        in attributedString: NSMutableAttributedString
    ) {
        let fullText = attributedString.string as NSString
        var searchRange = NSRange(location: 0, length: fullText.length)

        while true {
            let range = fullText.range(of: placeholder, options: [], range: searchRange)
            if range.location == NSNotFound { break }

            let currentAttributes = attributedString.attributes(at: range.location, effectiveRange: nil)
            let newValue = NSMutableAttributedString(attributedString: value)
            newValue.addAttributes(currentAttributes, range: NSRange(location: 0, length: newValue.length))

            attributedString.replaceCharacters(in: range, with: newValue)
            let newLocation = range.location + newValue.length
            searchRange = NSRange(location: newLocation, length: attributedString.length - newLocation)
        }
    }

    private static func buildSessionsTableText(sessions: [TreatmentSessions], spec: SessionTableSpec) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let paragraphStyle = NSMutableParagraphStyle()
        var location: CGFloat = 0
        paragraphStyle.tabStops = spec.columns.map { col in
            defer { location += col.width }
            return NSTextTab(textAlignment: col.alignment, location: location)
        }
        paragraphStyle.defaultTabInterval = 0

        let headerLine = NSMutableAttributedString()
        for (index, col) in spec.columns.enumerated() {
            headerLine.append(NSAttributedString(string: col.title, attributes: [
                .font: UIFont(name: col.fontName, size: col.fontSize + 1)?.bold() ?? UIFont.boldSystemFont(ofSize: col.fontSize + 1)
            ]))
            if index < spec.columns.count - 1 {
                headerLine.append(NSAttributedString(string: "\t"))
            }
        }
        headerLine.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: headerLine.length))
        headerLine.append(NSAttributedString(string: "\n"))
        result.append(headerLine)

        for (rowIndex, session) in sessions.enumerated() {
            let rowLine = NSMutableAttributedString()
            for (colIndex, col) in spec.columns.enumerated() {
                let cell = col.valueBuilder(session, rowIndex)
                rowLine.append(NSAttributedString(string: cell.text, attributes: [
                    .font: UIFont(name: col.fontName, size: col.fontSize) ?? UIFont.systemFont(ofSize: col.fontSize)
                ]))
                if colIndex < spec.columns.count - 1 {
                    rowLine.append(NSAttributedString(string: "\t"))
                }
            }
            rowLine.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: rowLine.length))
            rowLine.append(NSAttributedString(string: "\n"))
            result.append(rowLine)
        }

        return result
    }
    
    private static func buildRemediesTableText(remedies: [InvoiceServiceAggregation], spec: RemedyTableSpec) -> NSAttributedString {
        let result = NSMutableAttributedString()
        

        // ✅ 1: ParagraphStyle inkl. TabStops
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = 0

        var currentPosition: CGFloat = 0
        for col in spec.columns {
            let tab = NSTextTab(textAlignment: col.alignment, location: currentPosition)
            paragraphStyle.tabStops.append(tab)
            currentPosition += col.width
        }

        // ✅ 2: Überschrift
        let header = NSMutableAttributedString()
        for (i, col) in spec.columns.enumerated() {
            header.append(NSAttributedString(
                string: col.title,
                attributes: [
                    .font: UIFont(name: col.fontName, size: col.fontSize + 1)?.bold() ?? UIFont.boldSystemFont(ofSize: col.fontSize + 1)
                ]
            ))
            if i < spec.columns.count - 1 {
                header.append(NSAttributedString(string: "\t"))
            }
        }
        header.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: header.length))
        header.append(NSAttributedString(string: "\n"))
        result.append(header)

        // ✅ 3: Daten
        for (rowIndex, remedy) in remedies.enumerated() {
            let row = NSMutableAttributedString()
            for (i, col) in spec.columns.enumerated() {
                let cell = col.valueBuilder(remedy, rowIndex)
                row.append(NSAttributedString(
                    string: cell.text,
                    attributes: [
                        .font: UIFont(name: col.fontName, size: col.fontSize) ?? UIFont.systemFont(ofSize: col.fontSize)
                    ]
                ))
                if i < spec.columns.count - 1 {
                    row.append(NSAttributedString(string: "\t"))
                }
            }
            row.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: row.length))
            row.append(NSAttributedString(string: "\n"))
            result.append(row)
        }

        return result
    }

    private static func aggregateRemedies(from therapy: Therapy) -> [InvoiceServiceAggregation] {
        let allServices: [UUID: TreatmentService] = AppGlobals.shared.treatmentServices.reduce(into: [:]) { dict, service in
            dict[service.internalId] = service
        }

        var result: [String: InvoiceServiceAggregation] = [:]

        let allSessions = therapy.therapyPlans.flatMap { $0.treatmentSessions }

        for session in allSessions {
            for serviceId in session.treatmentServiceIds {
                guard let service = allServices[serviceId] else { continue }
                let key = service.de

                if var existing = result[key] {
                    existing.quantity += 1
                    result[key] = existing
                } else {
                    result[key] = InvoiceServiceAggregation(
                        serviceId: service.id,
                        serviceDescription: service.de,
                        billingCode: service.billingCode,
                        quantity: 1,
                        unitPrice: service.price ?? 0.0
                    )
                }
            }
        }

        return Array(result.values)
    }
}
