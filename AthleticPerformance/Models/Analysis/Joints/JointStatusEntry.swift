//
//  JointStatusEntry.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct JointStatusEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var joint: Joints
    var side: BodySides
    var movement: JointMovementPattern  
    var value: JointMeasurementValue
    var painQuality: PainQualities?
    var painLevel: PainLevels?
    var endFeeling: EndFeelings?
    var notes: String?
    var reevaluation: Bool = false
    var timestamp: Date
}

enum JointMeasurementValue: Codable, Hashable {
    case number(Double)
    case boolean(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .boolean(b)
        } else {
            throw DecodingError.typeMismatch(
                JointMeasurementValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Double or Bool")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let d): try container.encode(d)
        case .boolean(let b): try container.encode(b)
        }
    }
}
