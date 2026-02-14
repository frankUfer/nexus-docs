//
//  TreatmentService.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

/// Represents a treatment or service offered by a medical practice.
struct TreatmentService: Identifiable, Codable, Hashable {
    /// Internal unique identifier for the service.
    var internalId: UUID

    /// External or catalog identifier for the service (e.g., "MT").
    var id: String

    /// Service name in German.
    var de: String

    /// Service name in English.
    var en: String

    // MARK: - Billing

    /// Billing code for the service (e.g., "30201" according to the German Heilmittelkatalog).
    var billingCode: String?

    /// Quantity associated with the service (e.g., 20 for 20 minutes).
    var quantity: Int?

    /// Unit of measurement (e.g., "session", "min").
    var unit: String?

    /// Suggested price for the service (optional).
    var price: Double?

    /// Indicates whether the service is billable (e.g., for internal or combined services).
    var isBillable: Bool
    
    // MARK: - Init

       init(
           internalId: UUID = UUID(),
           id: String,
           de: String,
           en: String,
           billingCode: String? = nil,
           quantity: Int? = nil,
           unit: String? = nil,
           price: Double? = nil,
           isBillable: Bool = true
       ) {
           self.internalId = internalId
           self.id = id
           self.de = de
           self.en = en
           self.billingCode = billingCode
           self.quantity = quantity
           self.unit = unit
           self.price = price
           self.isBillable = isBillable
       }

    // MARK: - Localization

    /// Returns the localized name of the service based on the given locale.
    /// - Parameter locale: The locale code (e.g., "de" for German, "en" for English).
    /// - Returns: The service name in the specified language.
    func localizedName(for locale: String) -> String {
        switch locale {
        case "de": return de
        default: return en
        }
    }
}

