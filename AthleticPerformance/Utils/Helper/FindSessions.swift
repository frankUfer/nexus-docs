//
//  FindSessions.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 12.06.25.
//

import Foundation

func findSessions(
    for therapistId: Int,
    from date: Date,
    excluding therapyPlanId: UUID,
    in patients: [Patient]
) -> [TreatmentSessions] {
    patients
        .compactMap { $0.therapies }
        .flatMap { $0 }
        .compactMap { $0 }
        .flatMap { $0.therapyPlans }
        .filter { $0.id != therapyPlanId }
        .flatMap { $0.treatmentSessions }
        .filter { session in
            session.therapistId == therapistId &&
            session.date >= date
        }
}
