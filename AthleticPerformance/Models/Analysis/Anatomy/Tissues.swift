//
//  Tissues.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct TissuesFile: Codable {
    var version: Int
    var items: [Tissues]
}

struct Tissues: Identifiable, Codable, Hashable {
    let id: UUID
    var de: String
    var en: String
}

struct TissueStatesFile: Codable {
    var version: Int
    var items: [TissueStates]
}

struct TissueStates: Identifiable, Codable, Hashable {
    let id: UUID
    var de: String
    var en: String
}

extension Tissues {
    func localized(locale: Locale = .current) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return de
        default:   return en
        }
    }
}

extension TissueStates {
    func localized(locale: Locale = .current) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return de
        default:   return en
        }
    }
}
