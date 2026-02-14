//
//  InvoiceItem.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct InvoiceItem: Identifiable, Codable, Hashable {
    var id: UUID // = UUID()
    var sessionId: String
    var serviceId: String
    var serviceDate: Date
    var serviceDescription: String
    var billingCode: String?
    var quantity: Int
    var unitPrice: Double
    var notes: String?
    
    init(
            id: UUID = UUID(),
            sessionId: String,
            serviceId: String,
            serviceDate: Date = Date(),
            serviceDescription: String,
            billingCode: String? = "",
            quantity: Int,
            unitPrice: Double,
            notes: String? = nil
        ) {
            self.id = id
            self.sessionId = sessionId
            self.serviceId = serviceId
            self.serviceDate = serviceDate
            self.serviceDescription = serviceDescription
            self.billingCode = billingCode
            self.quantity = quantity
            self.unitPrice = unitPrice
            self.notes = notes
        }
}
