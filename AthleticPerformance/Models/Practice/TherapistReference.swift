//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

struct TherapistReferenceFile: Codable {
    var version: Int
    var items: [TherapistReference]
}

struct TherapistReference: Codable {
    var id: Int
}
