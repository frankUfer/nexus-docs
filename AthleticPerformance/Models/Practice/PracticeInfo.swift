//
//  PracticeInfo.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

struct PracticeInfoFile: Codable {
    var version: Int
    var items: [PracticeInfo]
}

/// Represents information about a medical practice or clinic.
struct PracticeInfo: Codable, Equatable, Hashable, Identifiable {
    /// Unique identifier for the practice.
    var id: Int

    /// Name of the practice or clinic.
    var name: String

    /// Address of the practice.
    var address: Address
    
    /// Address from where to start patient visits
    var startAddress: Address

    /// Contact phone number for the practice.
    var phone: String

    /// Contact email address for the practice.
    var email: String

    /// Website URL of the practice.
    var website: String
    
    var taxNumber: String
    
    var bank: String
    
    var iban: String
    
    var bic: String

    /// List of therapists working at the practice.
    var therapists: [Therapists]

    /// List of services or treatments offered by the practice.
    var services: [TreatmentService]
}

