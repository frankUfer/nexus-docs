//
//  AssessmentStatusEntry.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct AssessmentStatusEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var assessmentId: UUID
    var side: BodySides
    var finding: Bool
    var description: String
    var reevaluation: Bool = false
    var timestamp: Date
}
