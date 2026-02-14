//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.04.25.
//

import Foundation

// MARK: - Generic Load Function mit Version-Wrap
func loadParameterList<T: Codable>(from fileName: String) -> [T] {
    let fileManager = FileManager.default
    let documentsURL = getDocumentsDirectory().appendingPathComponent("resources/parameter/\(fileName).json")

    // Versuche erst Dokumentenordner
    if fileManager.fileExists(atPath: documentsURL.path) {
        do {
            let data = try Data(contentsOf: documentsURL)
            let wrapper = try JSONDecoder().decode(VersionedList<T>.self, from: data)
            return wrapper.items
        } catch {
            showErrorAlert(errorMessage: String(
                format: NSLocalizedString("errorLoadingFromDocuments", comment: "Error loading from documents folder")
            ))
        }
    }

    // Fallback Bundle
    if let bundleURL = Bundle.main.url(forResource: fileName, withExtension: "json") {
        do {
            let data = try Data(contentsOf: bundleURL)
            let wrapper = try JSONDecoder().decode(VersionedList<T>.self, from: data)
            return wrapper.items
        } catch {
            showErrorAlert(errorMessage: String(
                format: NSLocalizedString("errorLoadingFromBundle", comment: "Error loading from bundle folder")
            ))
        }
    }

    return []
}

// MARK: - Generic Save Function mit Version-Wrap
func saveParameterList<T: Codable>(_ list: [T], fileName: String, version: Int = 1) throws {
    let wrapper = VersionedList(version: version, items: list)
    let url = getDocumentsDirectory().appendingPathComponent("resources/parameter/\(fileName).json")
    let data = try JSONEncoder().encode(wrapper)

    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    try data.write(to: url, options: .atomic)
}

// MARK: - Gemeinsamer Version-Wrapper
struct VersionedList<T: Codable>: Codable {
    let version: Int
    let items: [T]
}

//// MARK: - Dokumentenverzeichnis ermitteln
func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}
