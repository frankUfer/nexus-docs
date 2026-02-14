//
//  PainStructure.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

import Foundation

struct PainStructuresFile: Codable {
    var version: Int
    var items: [PainStructures]
}

struct PainStructures: Identifiable, Codable, Hashable {
    let id: UUID
    var de: String
    var en: String
    
    func localized(locale: Locale = .current) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return de
        default:   return en
        }
    }
}
