//
//  PostalcodeCity.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 04.11.25.
//

import Foundation

public struct PostalcodeCity: Codable, Equatable, Hashable {
    public var postalCode: String
    public var city: String

    public init(postalCode: String, city: String) {
        let digits = postalCode.filter(\.isNumber)
        self.postalCode = digits.count < 5
            ? String(repeating: "0", count: 5 - digits.count) + digits
            : digits
        self.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
