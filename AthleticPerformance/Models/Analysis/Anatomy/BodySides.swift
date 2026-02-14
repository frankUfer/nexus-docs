//
//  BodySide.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

import Foundation

enum BodySides: String, Codable, CaseIterable {
    case left
    case right
    case bilateral

    var localized: String {
        NSLocalizedString("bodySide.\(self.rawValue)", comment: "")
    }
}
