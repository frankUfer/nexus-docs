//
//  ValidationService.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.04.25.
//

import Foundation

protocol Validatable {
    /// Validiert zusätzliche Regeln (z. B. mindestens eine Telefonnummer etc.)
    func validateCustomRules() -> [String]
    
    /// Gibt die Feldnamen zurück, die bei der Prüfung auf leere Inhalte übersprungen werden sollen
    func ignoredValidationFields() -> [String]
}

class ValidationService {
    static let shared = ValidationService()

    private init() {}

    func validate<T>(_ object: T, prefix: String = "") -> [String] {
        var missingFields: [String] = []

        let mirror = Mirror(reflecting: object)
        let ignoredFields = (object as? Validatable)?.ignoredValidationFields() ?? []

        for child in mirror.children {
            guard let label = child.label else { continue }

            if ignoredFields.contains(label) {
                continue
            }

            let value = child.value
            let fullLabel = prefix.isEmpty ? label : "\(prefix).\(label)"
            let childMirror = Mirror(reflecting: value)

            if childMirror.displayStyle == .optional {
                if childMirror.children.isEmpty {
                    missingFields.append(fullLabel)
                }
            } else if let str = value as? String, str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingFields.append(fullLabel)
            } else if let array = value as? [Any], array.isEmpty {
                missingFields.append(fullLabel)
            } else if childMirror.displayStyle == .struct || childMirror.displayStyle == .class {
                missingFields.append(contentsOf: validate(value, prefix: fullLabel))
            }
        }

        return missingFields
    }

    func validateRequiredFields<T>(_ object: T) -> [String] {
        var missing = validate(object, prefix: "")

        if let customValidatable = object as? Validatable {
            missing.append(contentsOf: customValidatable.validateCustomRules())
        }

        return missing
    }
}
