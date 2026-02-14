//
//  Assessments.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

struct AssessmentFile: Codable {
    var version: Int
    var items: [Assessments]
}

struct Assessments: Identifiable, Codable, Hashable {
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

extension Assessments: Equatable {
    static func == (lhs: Assessments, rhs: Assessments) -> Bool {
        lhs.id == rhs.id
    }
}
