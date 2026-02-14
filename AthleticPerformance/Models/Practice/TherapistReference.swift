//
//  TherapistReference.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct TherapistReferenceFile: Codable {
    var version: Int
    var items: [TherapistReference]
}

struct TherapistReference: Codable {
    var id: UUID

    enum CodingKeys: String, CodingKey {
        case id
    }

    init(id: UUID) {
        self.id = id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try decodeTherapistId(from: container, forKey: .id)
    }
}
