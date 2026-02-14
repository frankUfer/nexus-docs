//
//  StreetAbbreviator.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 10.07.25.
//

import Foundation

struct StreetAbbreviator {
    static let replacements: [(pattern: String, replacement: String)] = [
        ("straße", "str."),
        ("Strasse", "Str."),
        ("platz", "pl."),
        ("Platz", "Pl."),
        ("allee", "Al."),
        (" an der ", " a.d. "),
        (" am ", " a. "),
        (" bei ", " b. "),
        (" auf der ", " a.d. "),
        ("Auf Der ", " A.D. "),
    ]
    
    static func abbreviate(_ input: String) -> String {
        var output = input
        for (pattern, replacement) in replacements {
            output = output.replacingOccurrences(of: pattern, with: replacement, options: [.caseInsensitive, .regularExpression])
        }
        return output
    }
}
