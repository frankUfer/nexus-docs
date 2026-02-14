//
//  MuscleStatusEntry.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct MuscleStatusEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var muscleGroup: MuscleGroups
    var side: BodySides
    var tone: MuscleTone
    var mft: Int
    var painQuality: PainQualities?
    var painLevel: PainLevels?
    var notes: String?
    var reevaluation: Bool = false
    var timestamp: Date
}
