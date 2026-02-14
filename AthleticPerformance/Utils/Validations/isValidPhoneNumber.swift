//
//  isValidPhoneNumber.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.03.25.
//

import Foundation

func isValidPhoneNumber(_ number: String) -> Bool {
    let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
    let regex = "^[0-9+()\\-\\s]{5,}$" // erlaubt: Ziffern, +, (), - und Leerzeichen, mind. 5 Zeichen
    return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
}
