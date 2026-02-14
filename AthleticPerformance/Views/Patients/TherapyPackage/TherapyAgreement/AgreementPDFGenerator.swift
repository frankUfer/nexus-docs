//
//  AgreementPDFGenerator.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import UIKit
import PDFKit

struct AgreementPDFGenerator {
    static func generatePDF(
        plainText: String,
        patient: Patient,
        practiceInfo: PracticeInfo,
        therapy: Therapy,
        therapyId: UUID,
        place: String,
        date: Date,
        signature: UIImage? = nil
    ) -> URL? {
        let placeholderSpecs = defaultPlaceholderSpecs
        let markupSpecs = defaultMarkupSpecs
        let layout = defaultLayout
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: date)
        let signaturePlaceholders = makeSignaturePlaceholders(patientSignature: signature, layout: layout)

        let billingAddress = patient.addresses.first(where: { $0.value.isBillingAddress })?.value
        let context = PlaceholderContext(
            practice: practiceInfo,
            patient: patient,
            patientAddress: billingAddress,
            place: place,
            dateString: dateString,
            therapy: therapy
        )

        // 1️⃣ Platzhalter ersetzen
        var resolvedText = plainText
        for spec in placeholderSpecs {
            let value = spec.valueBuilder(context)
            resolvedText = resolvedText.replacingOccurrences(of: spec.key, with: value)
        }

        let lines = resolvedText.components(separatedBy: .newlines)
        let textWidth = layout.pageRect.width - layout.marginLeft - layout.marginRight

        let totalPages = lines.filter { MarkupPattern.detect(for: $0) == .pageBreak }.count + 1
        let renderer = UIGraphicsPDFRenderer(bounds: layout.pageRect)

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            var yTracker = layout.pageStart
            var pageCount = 1

            var currentBlock = NSMutableAttributedString()

            for line in lines {
                let pattern = MarkupPattern.detect(for: line)

                if pattern == .pageBreak {
                    // ➜ Footer + Block flushen
                    if currentBlock.length > 0 {
                        yTracker = renderBlock(atY: yTracker, attributed: currentBlock, layout: layout, textWidth: textWidth)
                        currentBlock = NSMutableAttributedString()
                    }
                    drawFooter(practiceName: practiceInfo.name, pageNumber: pageCount, totalPages: totalPages, layout: layout)
                    pageCount += 1
                    context.beginPage()
                    yTracker = layout.pageStart
                    continue
                }

                if line == "[[SESSIONS_OF_THERAPY]]" {
                    if currentBlock.length > 0 {
                        yTracker = renderBlock(atY: yTracker, attributed: currentBlock, layout: layout, textWidth: textWidth)
                        currentBlock = NSMutableAttributedString()
                    }
                    yTracker = renderSessionTable(atY: yTracker, therapy: therapy, layout: layout)
                    continue
                }

                if line == "[[REMEDIES_OF_THERAPY]]" {
                    if currentBlock.length > 0 {
                        yTracker = renderBlock(atY: yTracker, attributed: currentBlock, layout: layout, textWidth: textWidth)
                        currentBlock = NSMutableAttributedString()
                    }
                    yTracker = renderRemedyTable(atY: yTracker, therapy: therapy, layout: layout)
                    continue
                }
                
                if line == "[[TREATMENTS]]" {
                    if currentBlock.length > 0 {
                        yTracker = renderBlock(atY: yTracker, attributed: currentBlock, layout: layout, textWidth: textWidth)
                        currentBlock = NSMutableAttributedString()
                    }
                    yTracker = renderRemedyList(atY: yTracker, therapy: therapy, layout: layout)
                    continue
                }

                if line.contains("[[SIGNATURES]]") {
                    if currentBlock.length > 0 {
                        yTracker = renderBlock(atY: yTracker, attributed: currentBlock, layout: layout, textWidth: textWidth)
                        currentBlock = NSMutableAttributedString()
                    }

                    // ➜ Gemeinsame Höhe bestimmen
                    let maxWidth: CGFloat = 150
                    let heights: [CGFloat] = signaturePlaceholders.compactMap { placeholder in
                        guard let img = placeholder.signature else { return nil }
                        return maxWidth / (img.size.width / img.size.height)
                    }
                    let height = heights.max() ?? 0

                    // ➜ Jetzt alle gleich ausrichten
                    for placeholder in signaturePlaceholders {
                        guard let image = placeholder.signature else { continue }

                        let imageRect = CGRect(x: placeholder.xPosition, y: yTracker, width: maxWidth, height: height)
                        image.draw(in: imageRect)

                        // Untertitel nur, wenn Patient unterschrieben hat
                        if placeholder.label == "(Patient)" && placeholder.signature == nil {
                            continue
                        }

                        let font = UIFont.systemFont(ofSize: 10)
                        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                        let labelY = yTracker + height + 4
                        placeholder.label.draw(at: CGPoint(x: placeholder.xPosition, y: labelY), withAttributes: attrs)
                    }

                    // ➜ Einmal yTracker erhöhen
                    yTracker += height

                    continue
                }

                let spec = markupSpecs[pattern] ?? markupSpecs[.normal]!

                var cleanLine = line
                if pattern == .h1 { cleanLine.removeFirst(2) }
                if pattern == .h2 { cleanLine.removeFirst(3) }
                if pattern == .bullet { cleanLine.removeFirst(2) }

                var textToUse = cleanLine
                if pattern == .bullet, let bullet = spec.bulletSymbol {
                    textToUse = "\(bullet) \(cleanLine)"
                }

                let attributed = applyInlineMarkup(to: textToUse, baseSpec: spec)
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 2
                attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))

                currentBlock.append(attributed)
                currentBlock.append(NSAttributedString(string: "\n")) // ❗ Umbruch immer anhängen
            }

            // Letzten Block rendern
            if currentBlock.length > 0 {
                yTracker = renderBlock(atY: yTracker, attributed: currentBlock, layout: layout, textWidth: textWidth)
            }

            drawFooter(practiceName: practiceInfo.name, pageNumber: pageCount, totalPages: totalPages, layout: layout)
        }

        let folderURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("patients/\(patient.id)/therapy_\(therapyId)", isDirectory: true)

        let fileName = (signature == nil) ? "agreement_draft.pdf" : "agreement.pdf"
        let fileURL = folderURL.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            let message = "\(String(format: NSLocalizedString("errorSavingAgreement", comment: "Error saving agreement"))): \(error)"
          showErrorAlert(errorMessage: message)
            return nil
        }
    }

    private static func splitIntoSegments(line: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var temp = line

        while let boldRange = temp.range(of: #"(\*\*.+?\*\*)"#, options: .regularExpression) {
            let before = String(temp[..<boldRange.lowerBound])
            if !before.isEmpty {
                segments.append(TextSegment(text: before, isBold: false))
            }
            let boldText = temp[boldRange].dropFirst(2).dropLast(2)
            segments.append(TextSegment(text: String(boldText), isBold: true))
            temp = String(temp[boldRange.upperBound...])
        }

        if !temp.isEmpty {
            segments.append(TextSegment(text: temp, isBold: false))
        }

        return segments
    }

    private static func drawSimpleText(
        _ text: String,
        in rect: CGRect,
        isBold: Bool,
        alignment: NSTextAlignment,
        fontName: String,
        fontSize: CGFloat
    ) {
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
            .paragraphStyle: paragraph,
            .foregroundColor: UIColor.black
        ]

        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(in: rect)
    }

    private static func drawFooter(practiceName: String, pageNumber: Int, totalPages: Int, layout: PageLayoutSpec) {
        if let logo = UIImage(named: "AppLogo") {
            logo.draw(in: layout.logoRect)
        }

        let footerFont = UIFont(name: "Helvetica Neue", size: 7) ?? UIFont.systemFont(ofSize: 7)
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.black
        ]
        let footerY = layout.pageRect.height - layout.marginBottom - 15

        let footerText = "© \(practiceName)"
        let footerSize = footerText.size(withAttributes: footerAttrs)
        let footerX = (layout.pageRect.width - footerSize.width) / 2
        footerText.draw(at: CGPoint(x: footerX, y: footerY), withAttributes: footerAttrs)

        let pageNumberText = "Seite \(pageNumber) von \(totalPages)"
        let pageNumberSize = pageNumberText.size(withAttributes: footerAttrs)
        let pageNumberX = layout.pageRect.width - layout.marginRight - pageNumberSize.width
        pageNumberText.draw(at: CGPoint(x: pageNumberX, y: footerY), withAttributes: footerAttrs)
    }

    private static func renderSessionTable(atY yStart: CGFloat, therapy: Therapy, layout: PageLayoutSpec) -> CGFloat {
        var y = yStart
        let spec = defaultSessionTableSpec
        let sessions = therapy.therapyPlans.flatMap { $0.treatmentSessions }
        let rowGap: CGFloat = 4

        // 🟢 HEADER-ZEILE (ALLE Spalten nebeneinander)
        var x = layout.marginLeft
        for col in spec.columns {
            let rect = CGRect(x: x, y: y, width: col.width, height: col.fontSize + 2)
            drawSimpleText(col.title, in: rect, isBold: true, alignment: col.alignment, fontName: col.fontName, fontSize: col.fontSize)
            x += col.width
        }
        y += spec.columns.map { $0.fontSize }.max() ?? 11 + 4
        y += rowGap
        
        // 🟢 DATEN-ZEILEN
        for (rowIndex, session) in sessions.enumerated() {
            x = layout.marginLeft
            for col in spec.columns {
                let cell = col.valueBuilder(session, rowIndex)
                let rect = CGRect(x: x, y: y, width: col.width, height: col.fontSize + 2)
                drawSimpleText(cell.text, in: rect, isBold: false, alignment: col.alignment, fontName: col.fontName, fontSize: col.fontSize)
                x += col.width
            }
            y += spec.columns.map { $0.fontSize }.max() ?? 11 + 4
            y += rowGap / 2
        }

        return y + 8
    }

    private static func renderRemedyTable(atY yStart: CGFloat, therapy: Therapy, layout: PageLayoutSpec) -> CGFloat {
        var y = yStart
        let spec = defaultRemedyTableSpec
        let remedies = aggregateRemedies(from: therapy)
        let rowGap: CGFloat = 4

        // 🟢 HEADER-ZEILE (1x)
        var x = layout.marginLeft
        for col in spec.columns {
            let rect = CGRect(x: x, y: y, width: col.width, height: col.fontSize + 2)
            drawSimpleText(col.title, in: rect, isBold: true, alignment: col.alignment, fontName: col.fontName, fontSize: col.fontSize)
            x += col.width
        }
        y += spec.columns.map { $0.fontSize }.max() ?? 11 + 4
        y += rowGap

        // 🟢 DATEN-ZEILEN
        for (rowIndex, remedy) in remedies.enumerated() {
            x = layout.marginLeft
            for col in spec.columns {
                let cell = col.valueBuilder(remedy, rowIndex)
                let rect = CGRect(x: x, y: y, width: col.width, height: col.fontSize + 2)
                drawSimpleText(cell.text, in: rect, isBold: false, alignment: col.alignment, fontName: col.fontName, fontSize: col.fontSize)
                x += col.width
            }
            y += spec.columns.map { $0.fontSize }.max() ?? 11 + 4
            y += rowGap / 2
        }

        return y + 8
    }
    
    private static func aggregateRemedies(from therapy: Therapy) -> [InvoiceServiceAggregation] {
        let allServices: [UUID: TreatmentService] = AppGlobals.shared.treatmentServices.reduce(into: [:]) { dict, service in
            dict[service.internalId] = service
        }

        var result: [String: InvoiceServiceAggregation] = [:]
        let allSessions = therapy.therapyPlans.flatMap { $0.treatmentSessions }

        for session in allSessions {
            for serviceId in session.treatmentServiceIds {
                guard let service = allServices[serviceId] else { continue }
                let key = service.de
                if var existing = result[key] {
                    existing.quantity += 1
                    result[key] = existing
                } else {
                    result[key] = InvoiceServiceAggregation(
                        serviceId: service.id,
                        serviceDescription: service.de,
                        billingCode: service.billingCode,
                        quantity: 1,
                        unitPrice: service.price ?? 0.0
                    )
                }
            }
        }
        return Array(result.values)
    }
    
    private static func renderRemedyList(atY yStart: CGFloat, therapy: Therapy, layout: PageLayoutSpec) -> CGFloat {
        var y = yStart
        let remedies = aggregateRemedies(from: therapy)

        let bullet = "•"
        let fontName = "HelveticaNeue"
        let fontSize: CGFloat = 12
        let rowGap: CGFloat = 4

        for remedy in remedies {
            let text = "\(bullet) \(remedy.serviceDescription)"
            let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraph
            ]

            let textSize = (text as NSString).boundingRect(
                with: CGSize(width: layout.pageRect.width - layout.marginLeft - layout.marginRight, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            let rect = CGRect(
                x: layout.marginLeft,
                y: y,
                width: layout.pageRect.width - layout.marginLeft - layout.marginRight,
                height: ceil(textSize.height)
            )

            text.draw(in: rect, withAttributes: attrs)

            y += ceil(textSize.height) + rowGap
        }

        return y + 8
    }
    
    private static func renderBlock(atY y: CGFloat, attributed: NSAttributedString, layout: PageLayoutSpec, textWidth: CGFloat) -> CGFloat {
        let textRect = CGRect(x: layout.marginLeft, y: y, width: textWidth, height: .greatestFiniteMagnitude)
        let neededRect = attributed.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        attributed.draw(in: CGRect(
            x: textRect.minX,
            y: textRect.minY,
            width: textRect.width,
            height: ceil(neededRect.height)
        ))

        return y  + ceil(neededRect.height) - 12
    }
    
    private static func applyInlineMarkup(to line: String, baseSpec: MarkupSpec) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        var temp = line

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0  // Oder dein fixer Wert

        while let boldRange = temp.range(of: #"(\*\*.+?\*\*)"#, options: .regularExpression) {
            let before = String(temp[..<boldRange.lowerBound])
            result.append(NSAttributedString(string: before, attributes: [
                .font: UIFont(name: baseSpec.fontName, size: baseSpec.fontSize)!,
                .paragraphStyle: paragraphStyle
            ]))

            let boldText = temp[boldRange].dropFirst(2).dropLast(2)
            let boldFont = UIFont.boldSystemFont(ofSize: baseSpec.fontSize)
            result.append(NSAttributedString(string: String(boldText), attributes: [
                .font: boldFont,
                .paragraphStyle: paragraphStyle
            ]))

            temp = String(temp[boldRange.upperBound...])
        }

        result.append(NSAttributedString(string: temp, attributes: [
            .font: UIFont(name: baseSpec.fontName, size: baseSpec.fontSize)!,
            .paragraphStyle: paragraphStyle
        ]))

        return result
    }
    
    static func formatEuro(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE") // <- deutsches Komma
        return formatter.string(from: NSNumber(value: value)) ?? "0,00"
    }
}

struct TextSegment {
    let text: String
    let isBold: Bool
}
