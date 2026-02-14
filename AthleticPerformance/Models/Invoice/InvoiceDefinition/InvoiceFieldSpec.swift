//
//  InvoiceFieldSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import Foundation

struct InvoiceFieldSpec {
    /// Key zur Identifikation (z. B. "providerAddress")
    let key: String
    
    /// Beschreibung, was in diesem Feld steht (z. B. "Provider full address with name")
    let description: String
    
    /// Liefert eine Liste von formatierten Textstücken
    let valueBuilder: (Invoice) -> [InvoiceFieldContentPiece]
}

let defaultFieldBlockSpecs: [InvoiceFieldBlockSpec] = [

    // Provider Address
    InvoiceFieldBlockSpec(
        key: "providerAddress",
        description: "Provider full address with name",
        position: CGRect(x: pageWidth - right - 200, y: top + 70, width: 200, height: 100),
        style: InvoiceFieldBlockStyle(
            fontName: "HelveticaNeue",
            fontSize: 9,
            alignment: .right,
            lineSpacing: 4
        ),
        type: .text,
        valueBuilder: { invoice in
            let addr = invoice.providerAddress
            return [
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: invoice.providerName,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: addr.street,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: "\(addr.postalCode) \(addr.city)",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: invoice.date.formatted(date: .abbreviated, time: .omitted),
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("phone", comment: "Phone") + ": ",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.providerPhone,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("email", comment: "Email") + ": ",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.providerEmail,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("taxNumber", comment: "Tax number") + ": ",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.providerTaxId,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                )
            ]
        }
    ),

    // Customer Address
    InvoiceFieldBlockSpec(
        key: "customerAddress",
        description: "Customer address with street, postal code and city",
        position: CGRect(x: left, y: top + 70, width: 200, height: 50),
        style: InvoiceFieldBlockStyle(
            fontName: "HelveticaNeue",
            fontSize: 9,
            alignment: .left,
            lineSpacing: 4
        ),
        type: .text,
        valueBuilder: { invoice in
            let addr = invoice.patientAddress
            return [
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: invoice.patientName,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: addr.street,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: "\(addr.postalCode) \(addr.city)",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                )
            ]
        }
    ),

    // Invoice Number
    InvoiceFieldBlockSpec(
        key: "invoice",
        description: "Invoice",
        position: CGRect(x: left, y: top + 230, width: 200, height: 15),
        style: InvoiceFieldBlockStyle(
            fontName: "HelveticaNeue",
            fontSize: 9,
            alignment: .left,
            lineSpacing: 2
        ),
        type: .text,
        valueBuilder: { invoice in
            return [
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("invoice", comment: "Invoice") + ":   ",
                        isBold: true,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.invoiceNumber,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                )
            ]
        }
    ),

    // Invoice Basis
    InvoiceFieldBlockSpec(
        key: "invoiceBasis",
        description: "Invoice basis from Diagnosis",
        position: CGRect(x: left, y: top + 245, width: 450, height: 15),
        style: InvoiceFieldBlockStyle(
            fontName: "HelveticaNeue",
            fontSize: 9,
            alignment: .left,
            lineSpacing: 2
        ),
        type: .text,
        valueBuilder: { invoice in
            return [
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("basis", comment: "Basis") + ":   ",
                        isBold: true,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.invoiceBasis,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("basis", comment: "Basis") + "    ",
                        isBold: true,
                        isItalic: false,
                        color: .white
                    ),
                    content: InvoiceFieldContentPiece(
                        text: NSLocalizedString("from", comment: "From").lowercased() + " " + invoice.diagnosisSource + " - " + invoice.diagnosisDate,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                )
            ]
        }
    ),

    // Intro Text
    InvoiceFieldBlockSpec(
        key: "introText",
        description: "Intro text of the invoice",
        position: CGRect(x: left, y: top + 300, width: 450, height: 50),
        style: InvoiceFieldBlockStyle(
            fontName: "HelveticaNeue",
            fontSize: 9,
            alignment: .left,
            lineSpacing: 2
        ),
        type: .text,
        valueBuilder: { invoice in
            return [
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: NSLocalizedString("introText1", comment: "Intro text 1") + invoice.patientName + ",\n",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: NSLocalizedString("introText2", comment: "Intro text 2"),
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: NSLocalizedString("introText3", comment: "Intro text 3"),
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                )
            ]
        }
    ),

    
    // Tabelle mit Rechnungspositionen
    InvoiceFieldBlockSpec(
        key: "table",
        description: "Service table",
        position: CGRect(x: left, y: 400, width: 0, height: 0),
        style: InvoiceFieldBlockStyle(
            fontName: "",
            fontSize: 0,
            alignment: .left,
            lineSpacing: 2
        ),
        type: .table,
        valueBuilder: { _ in [] }
    ),
    
    // Final Text
    InvoiceFieldBlockSpec(
        key: "finalText",
        description: "Final text with due date and bank details",
        position: CGRect(x: left, y: 0, width: 450, height: 400),
        style: InvoiceFieldBlockStyle(
            fontName: "HelveticaNeue",
            fontSize: 9,
            alignment: .left,
            lineSpacing: 2
        ),
        type: .text,
        valueBuilder: { invoice in
            return [
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: "\n\n\n" + NSLocalizedString("noVAT", comment: "No VAT"),
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: NSLocalizedString("paymentTerms", comment: "Payment terms") + " " + invoice.dueDate.formatted(date: .abbreviated, time: .omitted) + ".\n",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("bank", comment: "Bank") + ": ",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.providerBank,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("iban", comment: "IBAN") + ": ",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.providerIBAN,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: InvoiceFieldContentPiece(
                        text: NSLocalizedString("bic", comment: "BIC") + ": ",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    ),
                    content: InvoiceFieldContentPiece(
                        text: invoice.providerBIC,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: "\n" + NSLocalizedString("invoiceClosureText1", comment: "Invoice closure text 1"),
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: NSLocalizedString("invoiceClosureText2", comment: "Invoice closure text 2") + "\n",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: NSLocalizedString("bestRegards", comment: "Best regards") + "\n",
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                ),
                InvoiceFieldPieceSpec(
                    label: nil,
                    content: InvoiceFieldContentPiece(
                        text: invoice.therapistFullName,
                        isBold: false,
                        isItalic: false,
                        color: .black
                    )
                )
            ]
        }
    )
]
