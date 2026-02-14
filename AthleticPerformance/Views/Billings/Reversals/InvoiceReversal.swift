//
//  InvoiceReversal.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 02.07.25.
//

import Foundation

@MainActor
func InvoiceReversal(_ invoice: Invoice, patientStore: PatientStore) throws {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let patientDir = documentsURL
        .appendingPathComponent("patients")
        .appendingPathComponent(invoice.patientId.uuidString)
        .appendingPathComponent("invoices")

        // 1️⃣ Neue Storno-Nummer
        var numberManager = NumberManager(fileName: "reversal_number_state.json", prefix: "REV-")
        let reversalNumber = numberManager.nextNumber(for: Date())
        
        // 2️⃣ Original-Rechnung als storniert markieren
        try InvoiceFileManager.markInvoiceAsReversed(invoice, reversalNumber: reversalNumber)

        // 3️⃣ Sessions zurücksetzen und Plan ermitteln
        let planId = try InvoiceFileManager.resetSessionsAfterReversal(invoice: invoice, in: patientStore)
    
        let hasDiagnosis: Bool = {
                // Patient holen
                guard let patient = patientStore.patients.first(where: { $0.id == invoice.patientId }) else {
                    return false
                }
                
                // Wir müssen die Therapy finden, in der der Plan steckt.
                // patient.therapies scheint ein Array optionaler Therapy? (du iterierst mit indices und guard var therapy = ...)
                // Wir durchsuchen alles linear:
                for case let therapy? in patient.therapies {
                    // Plan holen
                    if let plan = therapy.therapyPlans.first(where: { $0.id == planId }) {
                        // Hat der Plan eine diagnosisId?
                        guard let diagId = plan.diagnosisId else { return false }
                        // Existiert diese Diagnose in der Therapy?
                        let match = therapy.diagnoses.contains { $0.id == diagId }
                        return match
                    }
                }
                
                return false
            }()
        
        // 4️⃣ Neue Storno-Rechnung (negativ)
        let reversalItems = invoice.items.map { item in
            var newItem = item
            newItem.quantity = -abs(item.quantity)
            newItem.unitPrice = item.unitPrice
            return newItem
        }

        let subtotal = reversalItems.reduce(0.0) { $0 + (Double($1.quantity) * $1.unitPrice) }
        let taxRate = invoice.taxRate
        let totalAmount = subtotal * (1.0 + taxRate)
        let reversalAggregatedItems = invoice.aggregatedItems.map { $0.asReversal() }

        let reversalInvoice = Invoice(
            id: UUID(),
            invoiceType: .reversal,
            invoiceNumber: invoice.invoiceNumber,
            reversalNumber: reversalNumber,
            therapyPlanId: planId,
            invoiceBasis: invoice.invoiceBasis,
            diagnosisSource: invoice.diagnosisSource,
            diagnosisDate: invoice.diagnosisDate,
            date: Date(),
            dueDate: Date(),
            patientId: invoice.patientId,
            patientName: invoice.patientName,
            patientAddress: invoice.patientAddress,
            patientEmail: invoice.patientEmail,
            therapistFullName: invoice.therapistFullName,
            providerName: invoice.providerName,
            providerAddress: invoice.providerAddress,
            providerPhone: invoice.providerPhone,
            providerEmail: invoice.providerEmail,
            providerBank: invoice.providerBank,
            providerIBAN: invoice.providerIBAN,
            providerBIC: invoice.providerBIC,
            providerTaxId: invoice.providerTaxId,
            items: reversalItems,
            aggregatedItems: reversalAggregatedItems,
            subtotal: subtotal,
            taxRate: taxRate,
            totalAmount: totalAmount,
            pdfPath: patientDir.path,
            isCreated: true,
            isChecked: true,
            isSent: false,
            isReversed: false
        )

        let reversalJSONURL = patientDir.appendingPathComponent("\(reversalNumber).json")
        let reversalData = try JSONEncoder().encode(reversalInvoice)
        try reversalData.write(to: reversalJSONURL, options: .atomic)

        // 6️⃣ Storno-PDF generieren
        try generateInvoicePDF(
            invoice: reversalInvoice,
            aggregatedItems: reversalInvoice.aggregatedItems,
            fieldSpecs: defaultReversalFieldBlockSpecs,
            hasDiagnosis: hasDiagnosis
        )
        
        // Datei speichern
        InvoiceFileManager.saveInvoice(reversalInvoice)
    }
