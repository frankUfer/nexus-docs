//
//  CityAbbreviator.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 10.07.25.
//

import Foundation

struct CityAbbreviator {
    static let replacements: [(pattern: String, replacement: String)] = [
        (" am Main ", " a.M. "),
        (" an der Oder ", " a.d.O. "),
        (" am ", " a. "),
        (" bei ", " b. "),
        (" an der ", " a.d. "),
        ("Hünstetten-", "Hst.-"),
        ("Taunusstein-", "Tst.-"),
        ("Schwalbach-", "Schw.-"),
        (" am Taunus", ""),
        (" im Taunus", "")
    ]
    
    static func abbreviate(_ input: String) -> String {
        var output = input
        for (pattern, replacement) in replacements {
            output = output.replacingOccurrences(of: pattern, with: replacement, options: [.caseInsensitive, .regularExpression])
        }
        return output
    }
}
