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
    var id: UUID

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

    init(id: UUID = UUID(), firstname: String, lastname: String, email: String, isActive: Bool) {
        self.id = id
        self.firstname = firstname
        self.lastname = lastname
        self.email = email
        self.isActive = isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try decodeTherapistId(from: container, forKey: .id)
        firstname = try container.decode(String.self, forKey: .firstname)
        lastname = try container.decode(String.self, forKey: .lastname)
        email = try container.decode(String.self, forKey: .email)
        isActive = try container.decode(Bool.self, forKey: .isActive)
    }
}
