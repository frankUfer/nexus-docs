//
//  gender.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

/// Represents the gender of a person.
enum Gender: String, Codable, CaseIterable, Hashable {
    /// Male gender.
    case male
    /// Female gender.
    case female
    /// Diverse or non-binary gender.
    case diverse
    /// Gender is unknown or not specified.
    case unknown
}

