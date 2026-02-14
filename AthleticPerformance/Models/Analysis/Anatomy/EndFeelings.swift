//
//  EndFeel.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct EndFeelingsFile: Codable {
    var version: Int
    var items: [EndFeelings]
}

struct EndFeelings: Identifiable, Codable, Hashable {
    let id: UUID
    let de: String
    let en: String

    func localized(locale: Locale = .current) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return de
        default:   return en
        }
    }
}
