//
//  FileManagerHelper.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.04.25.
//

import Foundation

class FileManagerHelper {
    static let shared = FileManagerHelper()
    
    private init() {}
    
    func saveFile(named name: String, from sourceURL: URL) -> URL {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let targetURL = docsURL.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: targetURL) // falls bereits vorhanden
        try? FileManager.default.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }
}
