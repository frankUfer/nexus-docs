//
//  GenerateId.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.04.25.
//

import Foundation

func generateID(from name: String, existingIDs: Set<String>) -> String {
    var newID: String
    repeat {
        newID = UUID().uuidString
    } while existingIDs.contains(newID)
    return newID
}
