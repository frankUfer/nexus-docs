//
//  Joints.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct JointsFile: Codable {
    var version: Int
    var items: [Joints]
}

struct Joints: Identifiable, Codable, Hashable {
    let id: UUID
    var de: String
    var en: String
}

extension Joints {
    func localized(locale: Locale = .current) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return de
        default: return en
        }
    }
}

struct JointMovementPatternFile: Codable {
    var version: Int
    var items: [JointMovementPattern]
}

struct JointMovementPattern: Identifiable, Codable, Hashable {
    let id: UUID
    var de: String
    var en: String

    // Eingabetyp: z. B. "slider", "toggle", "picker"
    var inputType: InputType

    // Einheit: z. B. "deg", "cm", "bool"
    var unit: String?

    // Für "slider"/"number" gültig:
    var min: Double?
    var max: Double?
    var step: Double?
    var `default`: DoubleOrBool?
}

extension JointMovementPattern {
    func localized(locale: Locale = .current) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return de
        default:   return en
        }
    }
}

// Eingabetypen als Enum
enum InputType: String, Codable {
    case slider
    case toggle
    case number
    case picker
}

// Unterstützt Zahl oder Bool für default-Wert
enum DoubleOrBool: Codable, Hashable {
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else {
            throw DecodingError.typeMismatch(
                DoubleOrBool.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Bool or Double")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try container.encode(b)
        case .double(let d): try container.encode(d)
        }
    }
}
