//
//  Invoice.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct Invoice: Identifiable, Codable, Hashable {
    var id: UUID // = UUID()

    // 📅 Allgemeine Angaben
    var invoiceType: InvoiceType
    var invoiceNumber: String
    var reversalNumber: String?
    var therapyPlanId: UUID
    var invoiceBasis: String
    var diagnosisSource: String
    var diagnosisDate: String
    var date: Date
    var dueDate: Date

    // 👤 Empfänger
    var patientId: UUID
    var patientName: String
    var patientAddress: Address
    var patientEmail: String

    // 🏥 Praxis-/Absenderinformationen
    var therapistFullName: String
    var providerName: String
    var providerAddress: Address
    var providerPhone: String
    var providerEmail: String
    var providerBank: String
    var providerIBAN: String
    var providerBIC: String
    var providerTaxId: String
    
    
    // 🧾 Abgerechnete Positionen
    var items: [InvoiceItem]
    var aggregatedItems: [InvoiceServiceAggregation]
    
    // 💰 Beträge
    var subtotal: Double
    var taxRate: Double
    var totalAmount: Double

    // 📄 Ausgabe & Archiv
    var pdfPath: String
    var isCreated: Bool = false
    var isChecked: Bool = false
    var isSent: Bool = false
    var isReversed: Bool = false
    var isOverDue: Bool { dueDate < Date() }
    var isPaid: Bool = false
    var paymentDate: Date?
    var paymentMethod: String?        
    
    
    init(
        id: UUID = UUID(),
        invoiceType: InvoiceType,
        invoiceNumber: String,
        reversalNumber: String? = "",
        therapyPlanId: UUID,
        invoiceBasis: String,
        diagnosisSource: String,
        diagnosisDate: String,
        date: Date,
        dueDate: Date,
        patientId: UUID,
        patientName: String,
        patientAddress: Address,
        patientEmail: String,
        therapistFullName: String,
        providerName: String,
        providerAddress: Address,
        providerPhone: String,
        providerEmail: String,
        providerBank: String,
        providerIBAN: String,
        providerBIC: String,
        providerTaxId: String,
        items: [InvoiceItem],
        aggregatedItems: [InvoiceServiceAggregation] = [],
        subtotal: Double,
        taxRate: Double,
        totalAmount: Double,
        pdfPath: String = "",
        isCreated: Bool = false,
        isChecked: Bool = false,
        isSent: Bool = false,
        isReversed: Bool = false,
        isPaid: Bool = false,
        paymentDate: Date? = nil,
        paymentMethod: String? = nil
    ) {
        self.id = id
        self.invoiceType = invoiceType
        self.invoiceNumber = invoiceNumber
        self.reversalNumber = reversalNumber
        self.therapyPlanId = therapyPlanId
        self.invoiceBasis = invoiceBasis
        self.diagnosisSource = diagnosisSource
        self.diagnosisDate = diagnosisDate
        self.date = date
        self.dueDate = dueDate
        self.patientId = patientId
        self.patientName = patientName
        self.patientAddress = patientAddress
        self.patientEmail = patientEmail
        self.therapistFullName = therapistFullName
        self.providerName = providerName
        self.providerAddress = providerAddress
        self.providerPhone = providerPhone
        self.providerEmail = providerEmail
        self.providerBank = providerBank
        self.providerIBAN = providerIBAN
        self.providerBIC = providerBIC
        self.providerTaxId = providerTaxId
        self.items = items
        self.aggregatedItems = aggregatedItems
        self.subtotal = subtotal
        self.taxRate = taxRate
        self.totalAmount = totalAmount
        self.pdfPath = pdfPath
        self.isCreated = isCreated
        self.isChecked = isChecked
        self.isSent = isSent
        self.isReversed = isReversed
        self.isPaid = isPaid
        self.paymentDate = paymentDate
        self.paymentMethod = paymentMethod
    }
}

extension Invoice {
    var pdfFilename: String {
        URL(fileURLWithPath: pdfPath).lastPathComponent
    }
}

enum InvoiceType: String, Codable {
    case invoice = "invoice"
    case reversal = "reversal"
    case creditNote = "creditNote"
}
