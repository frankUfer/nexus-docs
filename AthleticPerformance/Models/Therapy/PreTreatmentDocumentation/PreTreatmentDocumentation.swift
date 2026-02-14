//
//  PreTreatmentDocumentation.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct PreTreatmentDocumentation: Identifiable, Codable, Hashable {
    var id: UUID // = UUID()
    var date: Date                          // Datum der Dokumentation
    var therapistId: UUID                   // Wer hat die Aufklärung durchgeführt

    // 🔹 Zielsetzung der Therapie
    var therapyGoals: String                // Beschreibung der Ziele
    var expectedOutcomes: String?           // Optional: Erwartete Ergebnisse

    // 🔹 Aufklärungsgespräch
    var topicsDiscussed: [String]           // Stichpunkte der besprochenen Themen
    var patientQuestions: String?           // Dokumentation der Fragen des Patienten
    var answersProvided: String?            // Antworten / Erläuterungen des Therapeuten
    var risksDiscussed: Bool                // Wurden Risiken besprochen?
    var patientUnderstood: Bool             // Hat Patient Verständnis bestätigt?

    // 🔹 Einverständniserklärung
    var contractGiven: Bool
    var contractDate: Date?
    var contractLocation: String?
    var signatureFile: MediaFile?

    var additionalNotes: String?

    enum CodingKeys: String, CodingKey {
        case id, date, therapistId, therapyGoals, expectedOutcomes,
             topicsDiscussed, patientQuestions, answersProvided,
             risksDiscussed, patientUnderstood, contractGiven,
             contractDate, contractLocation, signatureFile, additionalNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        therapistId = try decodeTherapistId(from: container, forKey: .therapistId)
        therapyGoals = try container.decode(String.self, forKey: .therapyGoals)
        expectedOutcomes = try container.decodeIfPresent(String.self, forKey: .expectedOutcomes)
        topicsDiscussed = try container.decode([String].self, forKey: .topicsDiscussed)
        patientQuestions = try container.decodeIfPresent(String.self, forKey: .patientQuestions)
        answersProvided = try container.decodeIfPresent(String.self, forKey: .answersProvided)
        risksDiscussed = try container.decode(Bool.self, forKey: .risksDiscussed)
        patientUnderstood = try container.decode(Bool.self, forKey: .patientUnderstood)
        contractGiven = try container.decode(Bool.self, forKey: .contractGiven)
        contractDate = try container.decodeIfPresent(Date.self, forKey: .contractDate)
        contractLocation = try container.decodeIfPresent(String.self, forKey: .contractLocation)
        signatureFile = try container.decodeIfPresent(MediaFile.self, forKey: .signatureFile)
        additionalNotes = try container.decodeIfPresent(String.self, forKey: .additionalNotes)
    }
}

extension PreTreatmentDocumentation {
    static func empty(therapistId: UUID) -> PreTreatmentDocumentation {
        PreTreatmentDocumentation(
            id: UUID(),
            date: Date(),
            therapistId: therapistId,
            therapyGoals: "",
            expectedOutcomes: nil,
            topicsDiscussed: [],
            patientQuestions: nil,
            answersProvided: nil,
            risksDiscussed: false,
            patientUnderstood: false,
            contractGiven: false,
            contractDate: nil,
            contractLocation: nil,
            signatureFile: nil,
            additionalNotes: nil
        )
    }
}
