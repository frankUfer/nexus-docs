//
//  RemedyTableColumnSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import SwiftUI

struct RemedyTableColumnSpec {
    let key: String
    let title: String
    let width: CGFloat
    let alignment: NSTextAlignment
    let fontName: String
    let fontSize: CGFloat
    let valueBuilder: (InvoiceServiceAggregation, Int) -> TableCellContent
}

struct RemedyTableSpec {
    let columns: [RemedyTableColumnSpec]
}

let defaultRemedyTableSpec = RemedyTableSpec(
    columns: [
        RemedyTableColumnSpec(
            key: "remedy",
            title: NSLocalizedString("remedy", comment: "Remedy"),
            width: 200,
            alignment: .left,
            fontName: "HelveticaNeue",
            fontSize: 12,
            valueBuilder: { item, _ in
                TableCellContent(
                    text: item.serviceDescription
                )
            }
        ),
        RemedyTableColumnSpec(
            key: "quantity",
            title: NSLocalizedString("quantity", comment: "Quantity"),
            width: 40,
            alignment: .right,
            fontName: "HelveticaNeue",
            fontSize: 12,
            valueBuilder: { item, _ in
                TableCellContent(
                    text: "\(item.quantity)",
                    isBold: false
                )
            }
        ),
        RemedyTableColumnSpec(
            key: "unitPrice",
            title: NSLocalizedString("unitPrice", comment: "Unit price"),
            width: 60,
            alignment: .right,
            fontName: "HelveticaNeue",
            fontSize: 12,
            valueBuilder: { item, _ in
                TableCellContent(
                    text: AgreementPDFGenerator.formatEuro(item.unitPrice)
                )
            }
        ),
        RemedyTableColumnSpec(
            key: "amount",
            title: NSLocalizedString("amount", comment: "Amount"),
            width: 70,
            alignment: .right,
            fontName: "HelveticaNeue",
            fontSize: 12,
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
