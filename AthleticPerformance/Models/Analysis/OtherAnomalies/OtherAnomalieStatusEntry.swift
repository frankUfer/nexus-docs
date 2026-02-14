//
//  OtherAnomalieStatusEntry.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct OtherAnomalieStatusEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var anomaly: String
    var bodyRegion: BodyRegionSelectionGroup?
    var bodyPart: BodyPart?
    var side: BodySides?
    var anomalyPains: AnomalyPains?
    var reevaluation: Bool = false
    var timestamp: Date
}
