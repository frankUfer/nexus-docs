//
//  PDFKitView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import PDFKit
import SwiftUI

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical

        // Dokument laden
        let document = PDFDocument(url: url)
        pdfView.document = document

        // Modus von der Seitenzahl abhängig wählen
        let pageCount = document?.pageCount ?? 0
        if pageCount > 1 {
            pdfView.displayMode = .singlePageContinuous
            pdfView.usePageViewController(false)   // wichtig bei >1 Seite
        } else {
            pdfView.displayMode = .singlePage
            pdfView.usePageViewController(true)
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Nur neu setzen, wenn sich die URL wirklich ändert
        if pdfView.document?.documentURL != url {
            let document = PDFDocument(url: url)
            pdfView.document = document

            let pageCount = document?.pageCount ?? 0
            if pageCount > 1 {
                pdfView.displayMode = .singlePageContinuous
                pdfView.usePageViewController(false)
            } else {
                pdfView.displayMode = .singlePage
                pdfView.usePageViewController(true)
            }
        }
    }
}
