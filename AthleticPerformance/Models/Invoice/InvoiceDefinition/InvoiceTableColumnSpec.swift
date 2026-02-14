//
//  InvoiceTableColumnSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import SwiftUI

struct InvoiceTableColumnSpec {
    let key: String
    let title: String
    let width: CGFloat
    let alignment: NSTextAlignment
    let fontName: String
    let fontSize: CGFloat
    let valueBuilder: (InvoiceServiceAggregation, Int) -> TableCellContent
}

struct InvoiceTableSpec {
    let columns: [InvoiceTableColumnSpec]
}

let defaultTableSpec = InvoiceTableSpec(
    columns: [
        InvoiceTableColumnSpec(
            key: "invoicePositions",
            title: NSLocalizedString("position", comment: "Position"),
            width: 50,
            alignment: .center,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { _, index in
                TableCellContent(
                    text: "\(10 + index * 10)",
                    isBold: false
                )
            }
        ),
        InvoiceTableColumnSpec(
            key: "remedies",
            title: NSLocalizedString("remedies", comment: "Remedies"),
            width: 80,
            alignment: .center,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                TableCellContent(
                    text: item.billingCode ?? ""
                )
            }
        ),
        InvoiceTableColumnSpec(
            key: "remedyDescription",
            title: NSLocalizedString("remedyDescription", comment: "Remedy description"),
            width: 150,
            alignment: .left,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                TableCellContent(
                    text: item.serviceDescription
                )
            }
        ),
        InvoiceTableColumnSpec(
            key: "quantity",
            title: NSLocalizedString("quantity", comment: "Quantity"),
            width: 50,
            alignment: .right,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                TableCellContent(
                    text: "\(item.quantity)",
                    isBold: false
                )
            }
        ),
        InvoiceTableColumnSpec(
            key: "unitPrice",
            title: NSLocalizedString("unitPrice", comment: "Unit price"),
            width: 60,
            alignment: .right,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                TableCellContent(
                    text: AgreementPDFGenerator.formatEuro(item.unitPrice)
                )
            }
        ),
        InvoiceTableColumnSpec(
            key: "amount",
            title: NSLocalizedString("amount", comment: "Amount"),
            width: 60,
            alignment: .right,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                let total = Double(item.quantity) * item.unitPrice
                return TableCellContent(
                    text: AgreementPDFGenerator.formatEuro(total),
                    isBold: false
                )
            }
        )
    ]
)
