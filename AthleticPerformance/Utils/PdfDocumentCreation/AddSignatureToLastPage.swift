//
//  addSignatureToLastPage.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.05.25.
//

import PDFKit
import UIKit

func addSignatureToLastPage(
    of existingContract: URL,
    saveTo archiveURL: URL,
    place: String,
    date: Date,
    signatureImageTherapist: UIImage,
    signatureImagePatient: UIImage,
    textLine: String,
    font: UIFont = .systemFont(ofSize: 11),
    textColor: UIColor = .black
) {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"

    guard let originalPDF = PDFDocument(url: existingContract),
          let lastPage = originalPDF.page(at: originalPDF.pageCount - 1),
          let pageRef = lastPage.pageRef else {
        return
    }

    let mediaBox = pageRef.getBoxRect(.mediaBox)

    let rendererFormat = UIGraphicsPDFRendererFormat()
    let renderer = UIGraphicsPDFRenderer(bounds: mediaBox, format: rendererFormat)

    let pdfData = renderer.pdfData { context in
        context.beginPage()

        let cgContext = context.cgContext
        cgContext.saveGState()

        // Ursprung von unten links → oben links verschieben (Flip Y-Achse)
        cgContext.translateBy(x: 0, y: mediaBox.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)

        // PDF-Seite korrekt zeichnen
        cgContext.drawPDFPage(pageRef)
        cgContext.restoreGState()

        // Zusatzinhalte (Text und Signaturen)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let leftMargin: CGFloat = defaultLayout.marginLeft
        let rightMargin: CGFloat = defaultLayout.marginRight
        let signatureHeight: CGFloat = 70
        let signatureWidth: CGFloat = 150
        let yPosition: CGFloat = defaultLayout.pageEnd - defaultLayout.marginBottom - 10
        let signaturePlaceholders = makeSignaturePlaceholders(patientSignature: signatureImagePatient, layout: defaultLayout)

        let attributedText = NSAttributedString(string: textLine, attributes: attributes)
        attributedText.draw(in: CGRect(x: leftMargin, y: yPosition + 20, width: mediaBox.width - leftMargin - rightMargin, height: 30))

        let ortDatum = "\(place), \(formatter.string(from: date))"
        let attributedOrtDatum = NSAttributedString(string: ortDatum, attributes: attributes)
        attributedOrtDatum.draw(in: CGRect(x: leftMargin, y: yPosition + 40, width: mediaBox.width - leftMargin - rightMargin, height: 20))

        drawSignature(signatureImageTherapist, at: CGPoint(x: leftMargin, y: yPosition + 60 + signatureHeight))
 
        let therapistLabel = NSAttributedString(string: "(Physiotherapeut)", attributes: attributes)
        let patientLabel = NSAttributedString(string: "(Patient)", attributes: attributes)
        therapistLabel.draw(in: CGRect(x: leftMargin, y: yPosition + 60 + signatureHeight, width: signatureWidth, height: 20))
        if let patientPlaceholder = signaturePlaceholders.first(where: { $0.label == "(Patient)" }) {
            patientLabel.draw(
                in: CGRect(
                    x: patientPlaceholder.xPosition,
                    y: yPosition + 60 + signatureHeight,
                    width: signatureWidth,
                    height: 20
                )
            )
            drawSignature(signatureImagePatient, at: CGPoint(x: patientPlaceholder.xPosition, y: yPosition + 60 + signatureHeight))
        }
    }

    // Neue Seite einfügen
    guard let modifiedPage = PDFDocument(data: pdfData)?.page(at: 0) else {
        return
    }

    originalPDF.removePage(at: originalPDF.pageCount - 1)
    originalPDF.insert(modifiedPage, at: originalPDF.pageCount)

    // Speichern
    originalPDF.write(to: archiveURL)
}

func drawSignature(_ image: UIImage, at point: CGPoint, maxWidth: CGFloat = 150) {
    let aspect = image.size.width / image.size.height
    let height = maxWidth / aspect
    let rect = CGRect(x: point.x, y: point.y - height, width: maxWidth, height: height)
    image.draw(in: rect)
}
