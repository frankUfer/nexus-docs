//
//  InvoiceServiceAggregation.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import Foundation

struct InvoiceServiceAggregation: Identifiable, Codable, Hashable {
    var id: UUID // = UUID()
    var serviceId: String
    var serviceDescription: String
    var billingCode: String?
    var quantity: Int
    var unitPrice: Double
    
    init(
            id: UUID = UUID(),
            serviceId: String,
            serviceDescription: String,
            billingCode: String? = "",
            quantity: Int,
            unitPrice: Double,
        ) {
            self.id = id
            self.serviceId = serviceId
            self.serviceDescription = serviceDescription
            self.billingCode = billingCode
            self.quantity = quantity
            self.unitPrice = unitPrice
        }
}

extension InvoiceServiceAggregation {
    func asReversal() -> InvoiceServiceAggregation {
        InvoiceServiceAggregation(
            id: self.id,
            serviceId: self.serviceId,
            serviceDescription: self.serviceDescription,
            billingCode: self.billingCode,
            quantity: -abs(self.quantity),
            unitPrice: self.unitPrice
        )
    }
}
