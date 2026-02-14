//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 25.05.25.
//

import Foundation

struct ReevaluationReferences: Codable, Hashable {
    var assessmentIds: [UUID] = []
    var jointIds: [UUID] = []
    var muscleIds: [UUID] = []
    var tissueIds: [UUID] = []
    var anomalyIds: [UUID] = []
    var symptomIds: [UUID] = []
}
