//
//  Patient.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.03.25.
//

import Foundation

struct PatientFile: Codable {
    var version: Int
    var patient: Patient
}

/// Represents a patient with personal, medical, and contact information.
struct Patient: Sendable, Codable, Equatable, Hashable, Identifiable {
    /// Unique identifier for the patient (UUID).
    var id: UUID  // = UUID()

    // MARK: - Basic Information

    /// Titel des Patienten
    var title: PatientTitle
    /// Firstname terms
    var firstnameTerms: Bool
    /// Patient's first name.
    var firstname: String
    /// Patient's last name.
    var lastname: String
    /// Patient's date of birth.
    var birthdate: Date
    /// Patient's gender.
    var sex: Gender

    // MARK: - Contact Information

    /// List of the patient's addresses.
    var addresses: [LabeledValue<Address>] = []
    /// List of the patient's phone numbers.
    var phoneNumbers: [LabeledValue<String>] = []
    /// List of the patient's email addresses.
    var emailAddresses: [LabeledValue<String>] = []
    /// List of the patient's emergency contacts.
    var emergencyContacts: [LabeledValue<EmergencyContact>] = []

    // MARK: - Insurance Information

    /// Patient's insurance status.
    var insuranceStatus: InsuranceStatus
    /// Name of the insurance provider (optional).
    var insurance: String?
    /// Insurance number (optional).
    var insuranceNumber: String?
    /// Name of the family doctor (optional).
    var familyDoctor: String?

    // MARK: - Medical History

    /// Patient's anamnesis (optional).
    var anamnesis: Anamnesis?

    // MARK: - Therapies

    /// List of the patient's therapies (optional).
    var therapies: [Therapy?]

    // MARK: - Activity Status

    /// Indicates whether the patient is currently active.
    var isActive: Bool = true

    /// Mahnstufe (0 = keine Mahnung, 1 = erste Mahnung, … 4 = letzte Mahnstufe)
    var dunningLevel: Int = 0

    /// Einschätzung des Zahlungsverhaltens
    var paymentBehavior: PaymentBehavior = .reliable

    /// Date when the patient record was created.
    var createdDate: Date

    /// Date when the patient record was last changed.
    var changedDate: Date

    enum CodingKeys: String, CodingKey {
        case id, title, firstnameTerms, firstname, lastname, birthdate, sex,
            addresses, phoneNumbers, emailAddresses, emergencyContacts,
            insuranceStatus, insurance, insuranceNumber, familyDoctor,
            anamnesis, therapies, isActive, dunningLevel, paymentBehavior,
            createdDate, changedDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(PatientTitle.self, forKey: .title)
        firstnameTerms =
            try c.decodeIfPresent(Bool.self, forKey: .firstnameTerms) ?? false
        firstname = try c.decode(String.self, forKey: .firstname)
        lastname = try c.decode(String.self, forKey: .lastname)
        birthdate = try c.decode(Date.self, forKey: .birthdate)
        sex = try c.decode(Gender.self, forKey: .sex)
        addresses =
            try c.decodeIfPresent(
                [LabeledValue<Address>].self,
                forKey: .addresses
            ) ?? []
        phoneNumbers =
            try c.decodeIfPresent(
                [LabeledValue<String>].self,
                forKey: .phoneNumbers
            ) ?? []
        emailAddresses =
            try c.decodeIfPresent(
                [LabeledValue<String>].self,
                forKey: .emailAddresses
            ) ?? []
        emergencyContacts =
            try c.decodeIfPresent(
                [LabeledValue<EmergencyContact>].self,
                forKey: .emergencyContacts
            ) ?? []
        insuranceStatus = try c.decode(
            InsuranceStatus.self,
            forKey: .insuranceStatus
        )
        insurance = try c.decodeIfPresent(String.self, forKey: .insurance)
        insuranceNumber = try c.decodeIfPresent(
            String.self,
            forKey: .insuranceNumber
        )
        familyDoctor = try c.decodeIfPresent(String.self, forKey: .familyDoctor)
        anamnesis = try c.decodeIfPresent(Anamnesis.self, forKey: .anamnesis)
        therapies =
            try c.decodeIfPresent([Therapy?].self, forKey: .therapies) ?? []
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        dunningLevel =
            try c.decodeIfPresent(Int.self, forKey: .dunningLevel) ?? 0
        paymentBehavior =
            try c.decodeIfPresent(
                PaymentBehavior.self,
                forKey: .paymentBehavior
            ) ?? .reliable
        createdDate = try c.decode(Date.self, forKey: .createdDate)
        changedDate = try c.decode(Date.self, forKey: .changedDate)
    }
}

/// Extension for validation functionality.
extension Patient: Validatable {
    /// Validates custom rules for the patient.
    /// - Returns: An array of field names that are invalid.
    func validateCustomRules() -> [String] {
        var issues: [String] = []

        // Check if all phone numbers are empty or whitespace.
        if phoneNumbers.allSatisfy({
            $0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }) {
            issues.append("phoneNumbers")
        }

        // Check if all email addresses are empty or whitespace.
        if emailAddresses.allSatisfy({
            $0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }) {
            issues.append("emailAddresses")
        }

        // Check if there is at least one address with non-empty street and city.
        let hasValidAddress = addresses.contains {
            !$0.value.street.trimmingCharacters(in: .whitespaces).isEmpty
                && !$0.value.city.trimmingCharacters(in: .whitespaces).isEmpty
        }
        if !hasValidAddress {
            issues.append("addresses")
        }

        return issues
    }

    /// Returns the fields that should be ignored during validation.
    /// - Returns: An array of field names to ignore.
    func ignoredValidationFields() -> [String] {
        return [
            "emergencyContacts",
            "therapies",
            "anamnesis",
        ]
    }
}

/// Extension for additional computed properties.
extension Patient {
    var fullName: String {
        if title.rawValue.isEmpty {
            return "\(firstname) \(lastname)"
        } else {
            return "\(title.rawValue) \(firstname) \(lastname)"
        }
    }
}

extension Patient {
    var fullNameWithLastNameFirst: String {
        if title.rawValue.isEmpty {
            return "\(lastname), \(firstname)"
        } else {
            return "\(lastname), \(title.rawValue) \(firstname)"
        }
    }
}

extension Patient {
    init(
        id: UUID = UUID(),
        title: PatientTitle,
        firstnameTerms: Bool = false,
        firstname: String,
        lastname: String,
        birthdate: Date,
        sex: Gender,
        insuranceStatus: InsuranceStatus,
        insurance: String? = nil,
        insuranceNumber: String? = nil,
        familyDoctor: String? = nil,
        anamnesis: Anamnesis? = nil,
        therapies: [Therapy?] = [],
        isActive: Bool = true,
        addresses: [LabeledValue<Address>] = [],
        phoneNumbers: [LabeledValue<String>] = [],
        emailAddresses: [LabeledValue<String>] = [],
        emergencyContacts: [LabeledValue<EmergencyContact>] = [],
        dunningLevel: Int = 0,
        paymentBehavior: PaymentBehavior = .reliable,
        createdDate: Date = Date(),
        changedDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.firstnameTerms = firstnameTerms
        self.firstname = firstname
        self.lastname = lastname
        self.birthdate = birthdate
        self.sex = sex
        self.addresses = addresses
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.emergencyContacts = emergencyContacts
        self.insuranceStatus = insuranceStatus
        self.insurance = insurance
        self.insuranceNumber = insuranceNumber
        self.familyDoctor = familyDoctor
        self.anamnesis = anamnesis
        self.therapies = therapies
        self.isActive = isActive
        self.dunningLevel = dunningLevel
        self.paymentBehavior = paymentBehavior
        self.createdDate = createdDate
        self.changedDate = changedDate
    }
}

enum PaymentBehavior: String, Codable, Equatable, Hashable, CaseIterable {
    case reliable = "reliable"  // immer pünktlich
    case lateSometimes = "lateSometimes"  // gelegentliche Verspätungen
    case chronicallyLate = "chronicallyLate"  // häufig verspätet
    case problematic = "problematic"  // sehr auffällig / schwierig
}
