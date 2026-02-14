//
//  ContractPDFGenerator.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import UIKit
import CoreText
import PDFKit

struct ContractPDFGenerator {
    static func generatePDF(
        plainText: String,
        patient: Patient,
        practiceInfo: PracticeInfo,
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
            therapy: Therapy.empty(patientId: patient.id)
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
                    yTracker += height //+ 4 + 10

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
            .appendingPathComponent("patients")
            .appendingPathComponent(patient.id.uuidString)

        let fileName = (signature == nil) ? "contract_draft.pdf" : "contract.pdf"
        let fileURL = folderURL.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            let message = "\(String(format: NSLocalizedString("errorSavingContract", comment: "Error saving contract"))): \(error)"
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
}
