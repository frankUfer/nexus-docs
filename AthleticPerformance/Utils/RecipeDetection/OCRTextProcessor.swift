//
//  OCRTextProcessor.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.04.25.
//

import Foundation

class OCRTextProcessor {
    
    /// Säubert und splittet den OCR-Text in Zeilen
    func preprocess(text: String) -> [String] {
        // 1. Trimmen
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Mehrfache Leerzeichen durch einfache ersetzen
        let normalizedText = trimmedText.replacingOccurrences(
            of: "[ \\t]+",  // Nur normales Leerzeichen und Tab ersetzen
            with: " ",
            options: .regularExpression
        )
                
        // 3. Zeilen aufteilen
        let lines = normalizedText.components(separatedBy: .newlines)
             
        // 4. Leere Zeilen entfernen
        let cleanedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
        
        return cleanedLines
    }
}
