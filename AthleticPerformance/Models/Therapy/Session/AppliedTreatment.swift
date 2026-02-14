//
//  AppliedTreatment.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 17.06.25.
//

import Foundation

struct AppliedTreatment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var serviceId: UUID
    var amount: Int
}
