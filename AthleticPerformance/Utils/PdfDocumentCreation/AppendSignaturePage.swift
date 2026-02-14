//
//  appendSignaturePage.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.05.25.
//

import PDFKit
import CoreGraphics
import UIKit

func appendSignaturePage(
    to existingContract: URL,
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

    guard let document = PDFDocument(url: existingContract) else {
        showErrorAlert(errorMessage: NSLocalizedString("errorLoadingPDF", comment: "Error loading PDF"))
        return
    }

    let pageWidth: CGFloat = 595.2  // A4-Breite in pt (72dpi)
    let pageHeight: CGFloat = 841.8 // A4-Höhe in pt

    let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

    // PDF-Kontext für neue Seite erstellen
    let pdfData = NSMutableData()
    UIGraphicsBeginPDFContextToData(pdfData, pageBounds, nil)
    UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
    guard UIGraphicsGetCurrentContext() != nil else { return }

    // Text zeichnen
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .left

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle
    ]

    let attributedText = NSAttributedString(string: textLine, attributes: attributes)
    attributedText.draw(in: CGRect(x: 40, y: 80, width: pageWidth - 80, height: 30))

    // Ort + Datum
    let ortDatum = "\(place), \(formatter.string(from: date))"
    let attributedOrtDatum = NSAttributedString(string: ortDatum, attributes: attributes)
    attributedOrtDatum.draw(in: CGRect(x: 40, y: 120, width: pageWidth - 80, height: 30))

    // Signaturen nebeneinander
    let signatureHeight: CGFloat = 80
    let signatureWidth: CGFloat = 200
    let yPosition: CGFloat = 180

    signatureImageTherapist.draw(in: CGRect(x: 60, y: yPosition, width: signatureWidth, height: signatureHeight))
    signatureImagePatient.draw(in: CGRect(x: pageWidth - signatureWidth - 60, y: yPosition, width: signatureWidth, height: signatureHeight))

    // Bezeichnungen unter den Unterschriften
    let therapistLabel = NSAttributedString(string: "Physiotherapeut", attributes: attributes)
    let patientLabel = NSAttributedString(string: "Patient", attributes: attributes)

    therapistLabel.draw(in: CGRect(x: 60, y: yPosition + signatureHeight + 10, width: signatureWidth, height: 20))
    patientLabel.draw(in: CGRect(x: pageWidth - signatureWidth - 60, y: yPosition + signatureHeight + 10, width: signatureWidth, height: 20))

    // Kontext als neue PDF-Seite sichern
    UIGraphicsEndPDFContext()

    // Neue Seite in Dokument einfügen
    if let newDoc = PDFDocument(data: pdfData as Data),
       let newPage = newDoc.page(at: 0) {
        document.insert(newPage, at: document.pageCount)
    }

    // PDF speichern
    document.write(to: archiveURL)
}
