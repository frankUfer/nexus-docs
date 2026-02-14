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
    var therapistId: UUID? = nil
    var status: DocStatus = .draft

    enum CodingKeys: String, CodingKey {
        case id, sessionId, notes, assessments, joints, muscles, tissues,
             otherAnomalies, symptoms, appliedTreatments, createdAt, updatedAt,
             therapistId, status
    }

    init(sessionId: UUID) {
        self.id = UUID()
        self.sessionId = sessionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        assessments = try container.decodeIfPresent([AssessmentStatusEntry].self, forKey: .assessments) ?? []
        joints = try container.decodeIfPresent([JointStatusEntry].self, forKey: .joints) ?? []
        muscles = try container.decodeIfPresent([MuscleStatusEntry].self, forKey: .muscles) ?? []
        tissues = try container.decodeIfPresent([TissueStatusEntry].self, forKey: .tissues) ?? []
        otherAnomalies = try container.decodeIfPresent([OtherAnomalieStatusEntry].self, forKey: .otherAnomalies) ?? []
        symptoms = try container.decodeIfPresent([SymptomsStatusEntry].self, forKey: .symptoms) ?? []
        appliedTreatments = try container.decodeIfPresent([AppliedTreatment].self, forKey: .appliedTreatments) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        therapistId = try decodeOptionalTherapistId(from: container, forKey: .therapistId)
        status = try container.decodeIfPresent(DocStatus.self, forKey: .status) ?? .draft
    }

    enum DocStatus: String, Codable {
        case draft, finalized
    }
}
