//
//  isValidEmail.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.03.25.
//

import Foundation

func isValidEmail(_ email: String) -> Bool {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    let regex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
    return NSPredicate(format: "SELF MATCHES[c] %@", regex).evaluate(with: trimmed)
}
