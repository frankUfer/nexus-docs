//
//  DiagnoseReferenceData.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 11.04.25.
//

struct DiagnoseReferenceDataFile: Codable {
    var version: Int
    var items: [DiagnoseReferenceData]
}

/// Container for categorized diagnosis reference data.
struct DiagnoseReferenceData: Codable {
    /// List of diagnosis categories and their associated terms.
    let diagnoseCategories: [DiagnoseCategory]
}

/// Represents a category of medical diagnoses with localized terms.
struct DiagnoseCategory: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German category name.
    var id: String { category_de }

    /// Category name in German (e.g., "Orthopädische Erkrankungen").
    let category_de: String

    /// Category name in English (e.g., "Orthopedic Conditions").
    let category_en: String

    /// List of diagnosis terms belonging to this category.
    let terms: [DiagnoseTerm]
}

/// Represents a single diagnosis term with localized names.
struct DiagnoseTerm: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German term.
    var id: String { de }

    /// Diagnosis term in German (e.g., "M54.5 Rückenschmerzen").
    let de: String

    /// Diagnosis term in English (e.g., "M54.5 Low back pain").
    let en: String
}

extension DiagnoseReferenceData {
    /// An empty instance used as a default/placeholder value.
    static let empty = DiagnoseReferenceData(diagnoseCategories: [])
}

