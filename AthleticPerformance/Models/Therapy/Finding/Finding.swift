//
//  Finding.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//

import Foundation

struct Finding: Identifiable, Codable, Hashable {
    var id: UUID
    var therapistId: UUID?
    var patientId: UUID
    var title: String = ""
    var date: Date = Date()
    var notes: String? = ""
    var mediaFiles: [MediaFile] = []

    var assessments: [AssessmentStatusEntry] = []
    var joints: [JointStatusEntry] = []
    var muscles: [MuscleStatusEntry] = []
    var tissues: [TissueStatusEntry] = []
    var otherAnomalies: [OtherAnomalieStatusEntry] = []
    var symptoms: [SymptomsStatusEntry] = []

    enum CodingKeys: String, CodingKey {
        case id, therapistId, patientId, title, date, notes, mediaFiles,
             assessments, joints, muscles, tissues, otherAnomalies, symptoms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        therapistId = try decodeOptionalTherapistId(from: container, forKey: .therapistId)
        patientId = try container.decode(UUID.self, forKey: .patientId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        mediaFiles = try container.decodeIfPresent([MediaFile].self, forKey: .mediaFiles) ?? []
        assessments = try container.decodeIfPresent([AssessmentStatusEntry].self, forKey: .assessments) ?? []
        joints = try container.decodeIfPresent([JointStatusEntry].self, forKey: .joints) ?? []
        muscles = try container.decodeIfPresent([MuscleStatusEntry].self, forKey: .muscles) ?? []
        tissues = try container.decodeIfPresent([TissueStatusEntry].self, forKey: .tissues) ?? []
        otherAnomalies = try container.decodeIfPresent([OtherAnomalieStatusEntry].self, forKey: .otherAnomalies) ?? []
        symptoms = try container.decodeIfPresent([SymptomsStatusEntry].self, forKey: .symptoms) ?? []
    }

    init(
        therapistId: UUID? = nil,
        patientId: UUID,
        title: String = "",
        date: Date = Date(),
        notes: String? = "",
        mediaFiles: [MediaFile] = [],
        assessments: [AssessmentStatusEntry] = [],
        joints: [JointStatusEntry] = [],
        muscles: [MuscleStatusEntry] = [],
        tissues: [TissueStatusEntry] = [],
        otherAnomalies: [OtherAnomalieStatusEntry] = [],
        symptoms: [SymptomsStatusEntry] = []
    ) {
        self.id = UUID()
        self.therapistId = therapistId
        self.patientId = patientId
        self.title = title
        self.date = date
        self.notes = notes
        self.mediaFiles = mediaFiles
        self.assessments = assessments
        self.joints = joints
        self.muscles = muscles
        self.tissues = tissues
        self.otherAnomalies = otherAnomalies
        self.symptoms = symptoms
    }
}
