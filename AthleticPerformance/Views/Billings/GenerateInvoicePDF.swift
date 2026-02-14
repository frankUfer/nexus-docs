//
//  GenerateInvoicePDF.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import UIKit

func generateInvoicePDF(
    invoice: Invoice,
    aggregatedItems: [InvoiceServiceAggregation],
    layout: PageLayoutSpec = defaultLayout,
    fieldSpecs: [InvoiceFieldBlockSpec] = defaultFieldBlockSpecs,
    tableSpec: InvoiceTableSpec = defaultTableSpec,
    hasDiagnosis: Bool
) throws {
    let renderer = UIGraphicsPDFRenderer(bounds: layout.pageRect)
    
    let data = renderer.pdfData { context in
        context.beginPage()
        
        // Logo oder Fallback zeichnen
        if let logo = UIImage(named: "AppLogo") {
            logo.draw(in: layout.logoRect)
        } else {
            let debugText = "LOGO?"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.red
            ]
            debugText.draw(at: layout.logoRect.origin, withAttributes: attributes)
        }
        
        var yTracker: CGFloat = layout.textStartY
        
        for block in fieldSpecs {
            let currentY: CGFloat
            
//            if block.key == "invoiceBasis",
//               (invoice.invoiceBasis.isEmpty || invoice.diagnosisSource.isEmpty) {
//                continue
//            }
            
            if block.key == "invoiceBasis",
               hasDiagnosis == false {
                continue
            }
            
            if block.position.origin.y == 0 {
                currentY = yTracker
            } else {
                currentY = block.position.origin.y
                yTracker = currentY
            }
            
            switch block.type {
            case .text:
                let pieces = block.valueBuilder(invoice)
                
                // Nur bei Text-Blöcken prüfen ob Inhalt vorhanden
                let hasContent = pieces.contains { piece in
                    let labelText = piece.label?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let contentText = piece.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return !labelText.isEmpty || !contentText.isEmpty
                }
                
                guard hasContent else {
                    continue // diesen Block überspringen
                }
                
                var blockYOffset: CGFloat = 0
                
                for piece in pieces {
                    let labelText = piece.label?.text ?? ""
                    let contentText = piece.content.text
                    let fullText = labelText + contentText
                    
                    let attributed = NSMutableAttributedString(string: fullText)
                    
                    // Absatzstil vorbereiten
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = block.style.alignment
                    paragraph.lineSpacing = block.style.lineSpacing
                    
                    var labelWidth: CGFloat = 0
                    if let label = piece.label {
                        let labelFont = makeFont(style: block.style, piece: label)
                        labelWidth = (label.text as NSString).size(withAttributes: [.font: labelFont]).width
                        paragraph.firstLineHeadIndent = 0
                        paragraph.headIndent = labelWidth
                    }
                    
                    // Grundattribute (Content-Style)
                    attributed.addAttributes([
                        .paragraphStyle: paragraph,
                        .foregroundColor: piece.content.color,
                        .font: makeFont(style: block.style, piece: piece.content)
                    ], range: NSRange(location: 0, length: attributed.length))
                    
                    // Label separat hervorheben
                    if let label = piece.label {
                        attributed.addAttributes([
                            .font: makeFont(style: block.style, piece: label),
                            .foregroundColor: label.color
                        ], range: NSRange(location: 0, length: labelText.count))
                    }
                    
                    let textRect = CGRect(
                        x: block.position.origin.x,
                        y: currentY + blockYOffset,
                        width: block.position.width,
                        height: .greatestFiniteMagnitude
                    )
                    
                    let neededRect = attributed.boundingRect(
                        with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    
                    attributed.draw(in: CGRect(
                        x: textRect.origin.x,
                        y: textRect.origin.y,
                        width: textRect.width,
                        height: ceil(neededRect.height)
                    ))
                    
                    blockYOffset += ceil(neededRect.height)
                }
                
                yTracker = currentY + blockYOffset + 4
                
            case .table:
                yTracker = renderTable(
                    atY: currentY,
                    tableSpec: tableSpec,
                    aggregatedItems: aggregatedItems,
                    layout: layout,
                    tableBlock: block
                )
                yTracker += 8
            }
        }
        
        // ➡ Anhang mit weiteren Seiten, wenn nötig
        if !invoice.items.isEmpty {
            renderItemReferencePages(
                context: context,
                invoice: invoice,
                items: invoice.items,
                layout: defaultReferenceLayout,
                fieldSpecs: defaultReferenceFieldSpecs,
                tableSpec: defaultItemReferenceTableSpec
            )
        }
    }
    
    let numberToUse: String
    switch invoice.invoiceType {
    case .invoice, .creditNote:
        numberToUse = invoice.invoiceNumber
    case .reversal:
        numberToUse = invoice.reversalNumber ?? "UNKNOWN"
    }
    
    InvoiceFileManager.saveInvoicePDF(data: data, for: invoice, usingNumber: numberToUse)
}

// MARK: - Hilfsfunktionen

func makeFont(style: InvoiceFieldBlockStyle, piece: InvoiceFieldContentPiece) -> UIFont {
    var traits: UIFontDescriptor.SymbolicTraits = []
    if piece.isBold { traits.insert(.traitBold) }
    if piece.isItalic { traits.insert(.traitItalic) }
    
    let baseFont = UIFont(name: style.fontName, size: style.fontSize) ?? UIFont.systemFont(ofSize: style.fontSize)
    if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
        return UIFont(descriptor: descriptor, size: style.fontSize)
    } else {
        return baseFont
    }
}

func drawSimpleText(_ text: String, in rect: CGRect, isBold: Bool, alignment: NSTextAlignment, fontName: String, fontSize: CGFloat) {
    let baseFont = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
    let font: UIFont
    if isBold {
        font = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor, size: fontSize)
    } else {
        font = baseFont
    }
    
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineSpacing = 2
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.black,
        .paragraphStyle: paragraph
    ]
    
    let attributed = NSAttributedString(string: text, attributes: attributes)
    attributed.draw(in: rect)
}

func columnRectX(_ column: InvoiceTableColumnSpec, block: InvoiceFieldBlockSpec, tableSpec: InvoiceTableSpec) -> CGFloat {
    var x = block.position.origin.x
    
    for col in tableSpec.columns {
        if col.key == column.key { break }
        x += col.width
    }
    
    return x
}

func renderTable(
    atY yStart: CGFloat,
    tableSpec: InvoiceTableSpec,
    aggregatedItems: [InvoiceServiceAggregation],
    layout: PageLayoutSpec,
    tableBlock: InvoiceFieldBlockSpec
) -> CGFloat {
    var y = yStart
    let maxFontSize = tableSpec.columns.map { $0.fontSize }.max() ?? 9

    // Helper: berechne linke X-Position der Tabelle
    func columnRectX(_ column: InvoiceTableColumnSpec) -> CGFloat {
        var x = tableBlock.position.origin.x
        for col in tableSpec.columns {
            if col.key == column.key { break }
            x += col.width
        }
        return x
    }

    // Header
    for column in tableSpec.columns {
        let rect = CGRect(
            x: columnRectX(column),
            y: y,
            width: column.width,
            height: column.fontSize + 2
        )
        drawSimpleText(
            column.title,
            in: rect,
            isBold: true,
            alignment: column.alignment,
            fontName: column.fontName,
            fontSize: column.fontSize
        )
    }
    y += maxFontSize + 4

    // Rows
    for (index, item) in aggregatedItems.enumerated() {
        for column in tableSpec.columns {
            let content = column.valueBuilder(item, index)
            let rect = CGRect(
                x: columnRectX(column),
                y: y,
                width: column.width,
                height: column.fontSize + 2
            )
            drawSimpleText(
                content.text,
                in: rect,
                isBold: content.isBold,
                alignment: column.alignment,
                fontName: column.fontName,
                fontSize: column.fontSize
            )
        }
        y += maxFontSize + 4
    }

    // Leere Zeile als Abstand
    y += maxFontSize + 4

    // Gesamtbetrag berechnen
    let totalAmount = aggregatedItems.reduce(0.0) { result, item in
        result + (Double(item.quantity) * item.unitPrice)
    }

    // Abschlusszeile: Total-Label + Betrag
    for (i, column) in tableSpec.columns.enumerated() {
        let rect = CGRect(
            x: columnRectX(column),
            y: y,
            width: column.width,
            height: column.fontSize + 2
        )

        if i == tableSpec.columns.count - 2 {
            drawSimpleText(
                NSLocalizedString("total", comment: "Total"),
                in: rect,
                isBold: true,
                alignment: column.alignment,
                fontName: column.fontName,
                fontSize: column.fontSize
            )
        } else if i == tableSpec.columns.count - 1 {
            drawSimpleText(
                AgreementPDFGenerator.formatEuro(totalAmount),
                in: rect,
                isBold: true,
                alignment: column.alignment,
                fontName: column.fontName,
                fontSize: column.fontSize
            )
        } else {
            drawSimpleText(
                "",
                in: rect,
                isBold: false,
                alignment: column.alignment,
                fontName: column.fontName,
                fontSize: column.fontSize
            )
        }
    }

    y += maxFontSize + 4

    return y
}
