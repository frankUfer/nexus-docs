//
//  EmergencyContact.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

/// Represents an emergency contact person for a patient.
struct EmergencyContact: Codable, Hashable {
    /// First name of the emergency contact.
    var firstname: String

    /// Last name of the emergency contact.
    var lastname: String

    /// Phone number of the emergency contact.
    var phone: String

    /// Email address of the emergency contact.
    var email: String
}

