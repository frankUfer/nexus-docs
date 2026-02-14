//
//  Address.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct Address: Codable, Equatable, Hashable {
    var street: String
    var postalCode: String
    var city: String
    var country: String = NSLocalizedString("germany", comment: "Germany")
    var isBillingAddress: Bool = false

    var latitude: Double? = nil
    var longitude: Double? = nil

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var fullDescription: String {
        "\(street), \(postalCode) \(city)"
    }

    func isSameLocation(as other: Address) -> Bool {
        self.street == other.street &&
        self.postalCode == other.postalCode &&
        self.city == other.city
    }
    
    init(
        street: String,
        postalCode: String,
        city: String,
        country: String = NSLocalizedString("germany", comment: "Germany"),
        isBillingAddress: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.street = street
        self.postalCode = postalCode
        self.city = city
        self.country = country
        self.isBillingAddress = isBillingAddress
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension Address {
    static func empty() -> Address {
        Address(street: "", postalCode: "", city: "")
    }
}

extension Address {
    var cacheKey: String {
        [street, postalCode, city].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }
}
