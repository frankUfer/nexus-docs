//
//  RenderItemReferencePages.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 24.06.25.
//

import UIKit

func renderItemReferencePages(
    context: UIGraphicsPDFRendererContext,
    invoice: Invoice,
    items: [InvoiceItem],
    layout: ReferenceLayoutSpec,
    fieldSpecs: [InvoiceFieldBlockSpec],
    tableSpec: ItemReferenceTableSpec
) {
    guard let tableBlock = fieldSpecs.first(where: { $0.key == "table" }) else {
        fatalError("No table block defined in fieldSpecs")
    }
    
    let tableStartX = tableBlock.position.origin.x
    
    let maxFontSize = tableSpec.columns.map { $0.fontSize }.max() ?? 9
    let rowHeight: CGFloat = maxFontSize + 4
    let usableHeight = layout.pageRect.height - layout.marginTop - layout.marginBottom
    let headerHeight: CGFloat = layout.tableStartY - layout.marginTop
    let footerHeight: CGFloat = 10
    let maxRowsPerPage = Int((usableHeight - headerHeight - footerHeight) / rowHeight)

    let totalRows = items.count + 2
    let totalPages = Int(ceil(Double(totalRows) / Double(maxRowsPerPage)))
    var currentPage = 1
    var itemIndex = 0

    while itemIndex < items.count || currentPage <= totalPages {
        context.beginPage()

        if let logo = UIImage(named: "AppLogo") {
            logo.draw(in: layout.logoRect)
        }

        if let headerBlock = fieldSpecs.first(where: { $0.key == "header" }) {
            let pieces = headerBlock.valueBuilder(invoice)
            var y = headerBlock.position.origin.y
            for piece in pieces {
                let font = UIFont(name: headerBlock.style.fontName, size: headerBlock.style.fontSize)
                    ?? UIFont.systemFont(ofSize: headerBlock.style.fontSize)
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = headerBlock.style.alignment
                paragraph.lineSpacing = headerBlock.style.lineSpacing
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: piece.content.color,
                    .paragraphStyle: paragraph
                ]
                let attrStr = NSAttributedString(string: piece.content.text, attributes: attributes)
                let rect = CGRect(x: headerBlock.position.origin.x, y: y,
                                  width: headerBlock.position.width, height: .greatestFiniteMagnitude)
                let neededRect = attrStr.boundingRect(
                    with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                )
                attrStr.draw(in: rect)
                y += ceil(neededRect.height) + 4
            }
        }

        var y = tableBlock.position.origin.y
        for col in tableSpec.columns {
            let rect = CGRect(
                x: columnRefRectX(col, startX: tableStartX, tableSpec: tableSpec),
                y: y,
                width: col.width,
                height: rowHeight
            )
            drawSimpleText(
                col.title,
                in: rect,
                isBold: true,
                alignment: col.alignment,
                fontName: col.fontName,
                fontSize: col.fontSize
            )
        }
        y += rowHeight

        var rowsOnPage = 0
        while itemIndex < items.count && rowsOnPage < maxRowsPerPage {
            let item = items[itemIndex]
            for col in tableSpec.columns {
                let content = col.valueBuilder(item, itemIndex)
                let rect = CGRect(
                    x: columnRefRectX(col, startX: tableStartX, tableSpec: tableSpec),
                    y: y,
                    width: col.width,
                    height: rowHeight
                )
                drawSimpleText(content.text, in: rect, isBold: content.isBold,
                               alignment: col.alignment,
                               fontName: col.fontName,
                               fontSize: col.fontSize)
            }
            y += rowHeight
            itemIndex += 1
            rowsOnPage += 1
        }

        if itemIndex >= items.count {
            if rowsOnPage < maxRowsPerPage {
                y += rowHeight
                rowsOnPage += 1
            }
            let totalAmount = items.reduce(0.0) { $0 + Double($1.quantity) * $1.unitPrice }
            for (i, col) in tableSpec.columns.enumerated() {
                let rect = CGRect(
                    x: columnRefRectX(col, startX: tableStartX, tableSpec: tableSpec),
                    y: y,
                    width: col.width,
                    height: rowHeight
                )
                if i == tableSpec.columns.count - 2 {
                    drawSimpleText(NSLocalizedString("total", comment: "Total"),
                                   in: rect, isBold: true,
                                   alignment: col.alignment,
                                   fontName: col.fontName,
                                   fontSize: col.fontSize)
                } else if i == tableSpec.columns.count - 1 {
                    drawSimpleText(
                       AgreementPDFGenerator.formatEuro(totalAmount),
                       in: rect, isBold: true,
                       alignment: col.alignment,
                       fontName: col.fontName,
                       fontSize: col.fontSize)
                } else {
                    drawSimpleText("", in: rect, isBold: false,
                                   alignment: col.alignment,
                                   fontName: col.fontName,
                                   fontSize: col.fontSize)
                }
            }
            y += rowHeight
        }

        let footerText = "\(NSLocalizedString("page", comment: "Page")) \(currentPage) / \(totalPages)"

        let footerRect = CGRect(
            x: layout.marginLeft,
            y: layout.pageRect.height - layout.marginBottom - footerHeight,
            width: layout.pageRect.width - layout.marginLeft - layout.marginRight,
            height: footerHeight
        )

        drawSimpleText(
            footerText,
            in: footerRect,
            isBold: false,
            alignment: .right,
            fontName: "HelveticaNeue",
            fontSize: 9
        )
        currentPage += 1
        if itemIndex >= items.count {
            break
        }
    }
}

func columnRefRectX(
    _ column: ItemReferenceTableColumnSpec,
    startX: CGFloat,
    tableSpec: ItemReferenceTableSpec
) -> CGFloat {
    var x = startX
    for col in tableSpec.columns {
        if col.key == column.key { break }
        x += col.width
    }
    return x
}
