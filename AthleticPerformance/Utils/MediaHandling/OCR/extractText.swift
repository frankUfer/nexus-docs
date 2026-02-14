//
//  extractText.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 26.04.25.
//

import Foundation


func extractText(from fileURL: URL, completion: @escaping (String?) -> Void) {
    // Überprüfen, ob es sich um eine PDF handelt
    if fileURL.pathExtension.lowercased() == "pdf" {
        // Extrahiere Text aus PDF
        extractTextFromPDF(pdfURL: fileURL, completion: completion)
    } else if ["jpg", "jpeg", "png", "tiff"].contains(fileURL.pathExtension.lowercased()) {
        // Extrahiere Text aus Bild
        extractTextFromImage(imageURL: fileURL, completion: completion)
    } else {
        completion(nil)
    }
}
