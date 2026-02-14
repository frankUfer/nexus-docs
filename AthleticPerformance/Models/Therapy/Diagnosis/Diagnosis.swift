//
//  Diagnosis.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct Diagnosis: Identifiable, Codable, Hashable {
    var id: UUID  // ()

    var therapyId: UUID
    var title: String = ""
    var date: Date = Date()
    var source: DiagnosisSource
    var treatments: [DiagnosisTreatments] = []
    var notes: String? = ""
    var mediaFiles: [MediaFile] = []
    
    init(
            id: UUID = UUID(),
            therapyId: UUID = UUID(),
            title: String = "",
            date: Date = Date(),
            source: DiagnosisSource,
            treaments: [DiagnosisTreatments] = [],
            notes: String? = "",
            mediaFiles: [MediaFile] = []
        ) {
            self.id = id
            self.therapyId = therapyId
            self.title = title
            self.date = date
            self.source = source
            self.treatments = treaments
            self.notes = notes
            self.mediaFiles = mediaFiles
        }
}

extension Diagnosis {
    static func empty(with therapyId: UUID) -> Diagnosis {
        return Diagnosis(
            therapyId: therapyId,
            source: DiagnosisSource(
                id: UUID().uuidString,
                originName: "",
                street: "",
                postalCode: "",
                city: "",
                phoneNumber: "",
                specialty: nil,
                createdAt: Date()
            )
        )
    }
}

