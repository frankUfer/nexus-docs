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
    var therapistId: Int                     // Verantwortlicher Therapeut

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
            therapistId: Int,
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
}
