//
//  DiagnosisSource.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct DiagnosisSource: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var originName: String = ""

    // Vereinfachte Adresse:
    var street: String = ""
    var postalCode: String = ""
    var city: String = ""

    var phoneNumber: String = ""
    var specialty: Specialty? = nil
    var createdAt: Date = Date()
    
    init(
            id: String = UUID().uuidString,
            originName: String = "",
            street: String = "",
            postalCode: String = "",
            city: String = "",
            phoneNumber: String = "",
            specialty: Specialty? = nil,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.originName = originName
            self.street = street
            self.postalCode = postalCode
            self.city = city
            self.phoneNumber = phoneNumber
            self.specialty = specialty
            self.createdAt = createdAt
        }
}
