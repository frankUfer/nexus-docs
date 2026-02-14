//
//  PainQualities.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct PainQualitiesFile: Codable {
    var version: Int
    var items: [PainQualities]
}

struct PainQualities: Identifiable, Codable, Hashable {
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
