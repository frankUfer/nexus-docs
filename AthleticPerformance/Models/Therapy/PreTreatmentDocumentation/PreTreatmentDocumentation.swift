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
    var therapistId: Int                    // Wer hat die Aufklärung durchgeführt

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
}

extension PreTreatmentDocumentation {
    static func empty(therapistId: Int) -> PreTreatmentDocumentation {
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
