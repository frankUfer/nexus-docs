//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct SpecialtyFile: Codable {
    var version: Int
    var items: [Specialty]
}

/// Represents a medical specialty, with support for multiple languages.
struct Specialty: Codable, Identifiable, Equatable, Hashable {
    /// Unique identifier for the specialty (e.g., UUID).
    var id: String

    /// Dictionary of localized names for the specialty (e.g., ["de": "Immunologie", "en": "Immunology"]).
    var name: [String: String]

    /// Source of the specialty data (e.g., "central" or "user").
    var source: String

    /// Returns the localized name of the specialty for the given locale.
    /// Falls back to English or any available name if the locale is not found.
    /// - Parameter locale: The locale to use for localization (default is current locale).
    /// - Returns: The localized name as a string.
    func localizedName(locale: Locale = .current) -> String {
        let lang = locale.language.languageCode?.identifier ?? "en"
        return name[lang] ?? name["en"] ?? name.values.first ?? ""
    }
}
