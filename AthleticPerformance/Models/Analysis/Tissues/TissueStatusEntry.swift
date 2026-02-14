//
//  TissueStatusEntry.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct TissueStatusEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var tissue: Tissues
    var side: BodySides?
    var tissueStates: TissueStates?
    var painQuality: PainQualities?
    var painLevel: PainLevels?
    var notes: String?
    var reevaluation: Bool = false
    var timestamp: Date
}
