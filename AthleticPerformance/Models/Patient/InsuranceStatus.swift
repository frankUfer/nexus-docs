//
//  InsuranceStatus.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

/// Represents the insurance status of a patient.
enum InsuranceStatus: String, Codable, CaseIterable, Hashable {
    /// The patient has private insurance.
    case privateInsurance
    /// The patient pays for their own medical expenses.
    case selfPaying
    /// The patient has public (statutory) insurance.
    case publicInsurance
    /// The patient's insurance status is other or unspecified.
    case other
}

