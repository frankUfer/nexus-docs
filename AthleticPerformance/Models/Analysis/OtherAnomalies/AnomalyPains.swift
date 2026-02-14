//
//  AnomalyPains.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 25.05.25.
//

import Foundation

struct AnomalyPains: Identifiable, Codable, Hashable {
    let id: UUID
    var painStructure: PainStructures?
    var painQuality: PainQualities?
    var painLevel: PainLevels?
    var notes: String?
    var timestamp: Date
}
