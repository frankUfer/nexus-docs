//
//  extractTextFromImage.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 26.04.25.
//

import Vision
import UIKit

func extractTextFromImage(imageURL: URL, completion: @escaping (String?) -> Void) {
    // Lade das Bild
    guard let image = UIImage(contentsOfFile: imageURL.path) else {
        completion(nil)
        return
    }
    
    // Konvertiere das Bild in CIImage für Vision
    guard let ciImage = CIImage(image: image) else {
        completion(nil)
        return
    }
    
    // Erstelle eine Text-Erkennungs-Anfrage
    let request = VNRecognizeTextRequest { request, error in
        if let error = error {
            let message = String(format: NSLocalizedString("errorTextRecognition", comment: "Error text recognition with file: %@"), error.localizedDescription)
            showErrorAlert(errorMessage: message)
            completion(nil)
            return
        }
        
        // Sammle den erkannten Text aus den Resultaten
        var recognizedText = ""
        for observation in request.results as? [VNRecognizedTextObservation] ?? [] {
            for text in observation.topCandidates(1) {
                recognizedText += text.string + "\n"
            }
        }
        
        // Rückgabe des erkannten Texts
        completion(recognizedText.isEmpty ? nil : recognizedText)
    }
    
    // Stelle sicher, dass Vision Text-Erkennung unterstützt wird
    request.recognitionLevel = .accurate
    
    // Starte die Anfrage
    let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    try? requestHandler.perform([request])
}
