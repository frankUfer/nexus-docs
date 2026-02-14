//
//  DischargeReport.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct DischargeReport: Identifiable, Codable, Hashable {
    var id: UUID // = UUID()
    var date: Date                           // Berichtserstellungsdatum
    var therapistId: UUID                    // Verantwortlicher Therapeut

    // 🔹 Inhalte des Berichts
    var diagnosisSummary: String
    var treatmentSummary: String
    var achievedGoals: String
    var remainingLimitations: String?
    var recommendations: String
    var additionalNotes: String?

    // 🔹 Medienanhänge (z. B. Fotos, Diagramme)
    var attachedMedia: [MediaFile] = []

    // 🔹 Formale Angaben für die PDF-Erstellung
    var signatureImagePath: String?          // Pfad zur Unterschrift (z. B. als PNG gespeichert)
    var signatureDate: Date?                 // Wann wurde der Bericht unterschrieben?
    var signaturePlace: String?              // Ort der Unterschrift
    var isFinalized: Bool = false            // Bericht abgeschlossen (nachträgliche Bearbeitung gesperrt)
    var pdfFilePath: String?                 // Optional: generierter PDF-Dateipfad
    
    init(
            id: UUID = UUID(),
            date: Date,
            therapistId: UUID,
            diagnosisSummary: String,
            treatmentSummary: String,
            achievedGoals: String,
            remainingLimitations: String? = nil,
            recommendations: String,
            additionalNotes: String? = nil,
            attachedMedia: [MediaFile] = [],
            signatureImagePath: String? = nil,
            signatureDate: Date? = nil,
            signaturePlace: String? = nil,
            isFinalized: Bool = false,
            pdfFilePath: String? = nil
        ) {
            self.id = id
            self.date = date
            self.therapistId = therapistId
            self.diagnosisSummary = diagnosisSummary
            self.treatmentSummary = treatmentSummary
            self.achievedGoals = achievedGoals
            self.remainingLimitations = remainingLimitations
            self.recommendations = recommendations
            self.additionalNotes = additionalNotes
            self.attachedMedia = attachedMedia
            self.signatureImagePath = signatureImagePath
            self.signatureDate = signatureDate
            self.signaturePlace = signaturePlace
            self.isFinalized = isFinalized
            self.pdfFilePath = pdfFilePath
        }

    enum CodingKeys: String, CodingKey {
        case id, date, therapistId, diagnosisSummary, treatmentSummary,
             achievedGoals, remainingLimitations, recommendations,
             additionalNotes, attachedMedia, signatureImagePath,
             signatureDate, signaturePlace, isFinalized, pdfFilePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        therapistId = try decodeTherapistId(from: container, forKey: .therapistId)
        diagnosisSummary = try container.decode(String.self, forKey: .diagnosisSummary)
        treatmentSummary = try container.decode(String.self, forKey: .treatmentSummary)
        achievedGoals = try container.decode(String.self, forKey: .achievedGoals)
        remainingLimitations = try container.decodeIfPresent(String.self, forKey: .remainingLimitations)
        recommendations = try container.decode(String.self, forKey: .recommendations)
        additionalNotes = try container.decodeIfPresent(String.self, forKey: .additionalNotes)
        attachedMedia = try container.decodeIfPresent([MediaFile].self, forKey: .attachedMedia) ?? []
        signatureImagePath = try container.decodeIfPresent(String.self, forKey: .signatureImagePath)
        signatureDate = try container.decodeIfPresent(Date.self, forKey: .signatureDate)
        signaturePlace = try container.decodeIfPresent(String.self, forKey: .signaturePlace)
        isFinalized = try container.decodeIfPresent(Bool.self, forKey: .isFinalized) ?? false
        pdfFilePath = try container.decodeIfPresent(String.self, forKey: .pdfFilePath)
    }
}
