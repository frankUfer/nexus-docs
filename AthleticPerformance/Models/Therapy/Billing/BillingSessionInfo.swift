//
//  BillingSessionInfo.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 20.06.25.
//

import Foundation


struct BillingSessionInfo {
    var patient: Patient
    var therapy: Therapy
    var plan: TherapyPlan
    var sessions: [TreatmentSessions]
    var status: BillingStatus
}

enum BillingStatus {
    case readyForInvoice
    case notYetInvoiceable
}
