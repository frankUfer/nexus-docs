//
//  Insurances.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 19.03.25.
//

struct InsuranceCompanyFile: Codable {
    var version: Int
    var items: [InsuranceCompany]
}

/// Represents a health insurance company.
struct InsuranceCompany: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier for the insurance company (e.g., a UUID).
    var id: String

    /// Name of the insurance company (e.g., "Alte Oldenburger").
    var name: String

    /// Source of the insurance company data (e.g., "central" or "user").
    /// Defaults to "user".
    var source: String = "user"
}
