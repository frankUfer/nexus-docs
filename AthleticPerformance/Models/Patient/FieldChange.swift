//
//  FieldChange.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 01.10.25.
//

import Foundation

/// Repräsentiert eine einzelne Feldänderung zwischen zwei Patient-Ständen
struct FieldChange {
    let path: String        // z. B. "/title" oder "/therapies/0/diagnoses/2"
    let oldValue: JSONValue    // alter Wert als String
    let newValue: JSONValue    // neuer Wert als String
    let therapistId: UUID?  // welcher Therapeut die Änderung verursacht hat (optional)
}

/// Primitive JSON-Darstellung zur Feldverfolgung
enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}
