//
//  TherapySessionDocumentation.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 17.06.25.
//

import Foundation

struct TherapySessionDocumentation: Identifiable, Codable, Hashable {
    var id: UUID
    var sessionId: UUID
    var notes: String = ""
    
    var assessments: [AssessmentStatusEntry] = []
    var joints: [JointStatusEntry] = []
    var muscles: [MuscleStatusEntry] = []
    var tissues: [TissueStatusEntry] = []
    var otherAnomalies: [OtherAnomalieStatusEntry] = []
    var symptoms: [SymptomsStatusEntry] = []
    var appliedTreatments: [AppliedTreatment] = []
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var therapistId: Int? = nil
    var status: DocStatus = .draft

    init(sessionId: UUID) {
        self.id = UUID()
        self.sessionId = sessionId
    }

    enum DocStatus: String, Codable {
        case draft, finalized
    }
}
