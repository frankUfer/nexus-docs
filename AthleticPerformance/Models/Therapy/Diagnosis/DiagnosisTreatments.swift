//
//  DiagnosisTreatments.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//

import Foundation

struct DiagnosisTreatments: Identifiable, Codable, Hashable {
    var id: UUID
    var number: Int = 10
    var description: String = ""
    var treatmentService: UUID?

    init(id: UUID = UUID(), number: Int = 10, description: String = "", treatmentService: UUID? = nil) {
        self.id = id
        self.number = number
        self.description = description
        self.treatmentService = treatmentService
    }
}
