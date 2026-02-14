//
//  ItemRefernceTableSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import SwiftUI

struct ItemReferenceTableColumnSpec {
    let key: String
    let title: String
    let width: CGFloat
    let alignment: NSTextAlignment
    let fontName: String
    let fontSize: CGFloat
    let valueBuilder: (InvoiceItem, Int) -> TableCellContent
}

struct ItemReferenceTableSpec {
    let columns: [ItemReferenceTableColumnSpec]
}

let defaultItemReferenceTableSpec = ItemReferenceTableSpec(
    columns: [

        ItemReferenceTableColumnSpec(
            key: "dates",
            title: NSLocalizedString("date", comment: "Date"),
            width: 60,
            alignment: .center,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .none
                let dateStr = formatter.string(from: item.serviceDate)
                return TableCellContent(text: dateStr)
            }
        ),
        ItemReferenceTableColumnSpec(
            key: "remedies",
            title: NSLocalizedString("remedies", comment: "Remedies"),
            width: 80,
            alignment: .center,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                TableCellContent(text: item.billingCode ?? "")
            }
        ),
        ItemReferenceTableColumnSpec(
            key: "remedyDescription",
            title: NSLocalizedString("remedyDescription", comment: "Remedy description"),
            width: 150,
            alignment: .left,
            fontName: "HelveticaNeue",
            fontSize: 9,
            valueBuilder: { item, _ in
                TableCellContent(text: item.serviceDescription)
            }
        ),
        ItemReferenceTableColumnSpec(
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
        ItemReferenceTableColumnSpec(
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
        ItemReferenceTableColumnSpec(
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
