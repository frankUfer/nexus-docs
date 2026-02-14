//
//  Symptom.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

import Foundation

struct SymptomsStatusEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var bodyRegion: BodyRegionSelectionGroup?
    var bodyPart: BodyPart?
    var side: BodySides?
    var problematicAction: String?
    var symptomPains: SymptomPains?
    var sinceDate: Date?
    var reevaluation: Bool = false
    var timestamp: Date
}
