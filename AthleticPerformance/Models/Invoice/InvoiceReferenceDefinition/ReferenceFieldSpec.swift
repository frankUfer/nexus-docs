//
//  ReferenceFieldSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import Foundation

struct ReferenceFieldSpec {
    /// Key zur Identifikation (z. B. "providerAddress")
    let key: String
    
    /// Beschreibung, was in diesem Feld steht (z. B. "Provider full address with name")
    let description: String
    
    /// Liefert eine Liste von formatierten Textstücken
    let valueBuilder: (Invoice) -> [InvoiceFieldContentPiece]
}

let defaultReferenceFieldSpecs: [InvoiceFieldBlockSpec] = [

    InvoiceFieldBlockSpec(
        key: "header",
        description: "Header with description, patient name and invoice number",
        position: CGRect(x: left, y: top + 70, width: 400, height: 20),
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
                        text: NSLocalizedString("itemReferences", comment: "Item references") + " " +
                              invoice.patientName + " - " +
                              NSLocalizedString("invoice", comment: "Invoice") + ": " +
                              invoice.invoiceNumber,
                        isBold: true,
                        isItalic: false,
                        color: .black
                    )
                )
            ]
        }
    ),
    
    // Tabelle mit Einzelnachweis
    InvoiceFieldBlockSpec(
        key: "table",
        description: "Service table",
        position: CGRect(x: left, y: top + 100, width: 0, height: 0),
        style: InvoiceFieldBlockStyle(
            fontName: "",
            fontSize: 0,
            alignment: .left,
            lineSpacing: 2
        ),
        type: .table,
        valueBuilder: { _ in [] }
    ),
]
