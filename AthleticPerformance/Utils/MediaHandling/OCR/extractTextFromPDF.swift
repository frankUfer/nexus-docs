//
//  extractTextFromPDF.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 26.04.25.
//

import PDFKit

func extractTextFromPDF(pdfURL: URL, completion: @escaping (String?) -> Void) {
    // Lade das PDF-Dokument
    guard let pdfDocument = PDFDocument(url: pdfURL) else {
        completion(nil)
        return
    }
    
    // Sammle den Text aus allen Seiten
    var extractedText = ""
    for pageIndex in 0..<pdfDocument.pageCount {
        if let page = pdfDocument.page(at: pageIndex) {
            extractedText += page.string ?? ""
        }
    }
    
    // Rückgabe des extrahierten Texts
    completion(extractedText.isEmpty ? nil : extractedText)
}
