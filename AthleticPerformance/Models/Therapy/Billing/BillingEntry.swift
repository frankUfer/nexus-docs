//
//  BillingEntry.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 20.06.25.
//

import Foundation


struct BillingEntry: Identifiable, Hashable {
    let id = UUID()

    let patient: Patient
    let therapy: Therapy
    let plan: TherapyPlan
    let service: TreatmentService
    let serviceDate: Date
    let sessionId: UUID
    let quantity: Int
    let volume: Double
    let isBillable: Bool
}
