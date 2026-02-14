//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

/// A generic structure that associates a value with a descriptive label.
/// Useful for storing labeled data such as addresses, phone numbers, or other contact information.
struct LabeledValue<T: Codable & Hashable>: Identifiable, Codable, Hashable {
    /// Unique identifier for the labeled value.
    var id = UUID()

    /// The label describing the value (e.g., "Home", "Work").
    var label: String

    /// The actual value associated with the label.
    var value: T

    /// Convenience initializer
    init(label: String, value: T) {
        self.label = label
        self.value = value
    }
}

extension LabeledValue {
    static var defaultLabels: [String] {
        ["private", "work", "other"]
    }
}
