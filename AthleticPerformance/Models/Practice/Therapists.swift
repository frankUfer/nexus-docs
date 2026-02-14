//
//  Therapists.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 19.03.25.
//

import Foundation

/// Represents a therapist's basic personal and contact information.
struct Therapists: Codable, Equatable, Hashable, Identifiable {
    /// Unique identifier for the therapist.
    var id: Int

    /// First name of the therapist.
    var firstname: String

    /// Last name of the therapist.
    var lastname: String

    /// Email address of the therapist.
    var email: String

    /// Indicates whether the therapist is currently active.
    var isActive: Bool

    /// The therapist's full name, combining first and last name.
    var fullName: String {
        "\(firstname) \(lastname)"
    }

    /// Coding keys for encoding and decoding the struct.
    enum CodingKeys: String, CodingKey {
        case id, firstname, lastname, email, isActive
    }
}
