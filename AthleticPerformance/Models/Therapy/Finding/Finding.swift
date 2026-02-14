//
//  Finding.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//

import Foundation

struct Finding: Identifiable, Codable, Hashable {
    var id: UUID
    var therapistId: Int?
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

    init(
        therapistId: Int? = nil,
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
