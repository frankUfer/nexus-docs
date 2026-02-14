//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 19.03.25.
//

import Foundation

///// Sets up required app directories in the user's document folder and optionally copies resource files into them.
///// - Parameter shouldCopyParameterData: If `true`, copies RTF and JSON resources from the app bundle into the appropriate folders.
///// - Returns: `true` if all directories were created and (if requested) all files were copied successfully, otherwise `false`.
func setupAppDirectories(shouldCopyParameterData: Bool) -> Bool {
    let fileManager = FileManager.default

    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        showErrorAlert(errorMessage: NSLocalizedString("errorDocumentFolderNotFound", comment: "Could not find document directory"))
        return false
    }

    let foldersToCreate = [
        "patients",
        "resources/templates",
        "resources/parameter"
    ]

    var success = true

    for folder in foldersToCreate {
        let folderURL = documentsURL.appendingPathComponent(folder)
        if !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                let errorMessage = String(
                    format: NSLocalizedString("errorCreatingFolder", comment: "Error creating folder %@: %@"),
                    folder,
                    error.localizedDescription
                )
                showErrorAlert(errorMessage: errorMessage)
                success = false
            }
        }
    }

    if shouldCopyParameterData {
        // RTF → templates
        success = success && copyResourcesToParameters(
            destinationURL: documentsURL.appendingPathComponent("resources/templates"),
            withExtensions: ["rtf"]
        )
        
        // TXT → templates
        success = success && copyResourcesToParameters(
            destinationURL: documentsURL.appendingPathComponent("resources/templates"),
            withExtensions: ["txt"]
        )

        // JSON → parameter
        success = success && copyResourcesToParameters(
            destinationURL: documentsURL.appendingPathComponent("resources/parameter"),
            withExtensions: ["json"]
        )
    }

    return success
}

func copyResourcesToParameters(destinationURL: URL, withExtensions extensions: [String]) -> Bool {
    let fileManager = FileManager.default
    var success = true

    guard let resourcePath = Bundle.main.resourcePath else {
        showErrorAlert(errorMessage: NSLocalizedString("errorResourcePathNotFound", comment: "Could not find resource path"))
        return false
    }

    let resourceURL = URL(fileURLWithPath: resourcePath)

    do {
        let resourceFiles = try fileManager.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

        let filteredFiles = resourceFiles.filter { file in
            extensions.contains(file.pathExtension.lowercased())
        }

        for file in filteredFiles {
            let destinationFileURL = destinationURL.appendingPathComponent(file.lastPathComponent)

            var shouldCopy = false

            if fileManager.fileExists(atPath: destinationFileURL.path) {
                do {
                    let sourceAttributes = try fileManager.attributesOfItem(atPath: file.path)
                    let destinationAttributes = try fileManager.attributesOfItem(atPath: destinationFileURL.path)

                    if let sourceDate = sourceAttributes[.modificationDate] as? Date,
                       let destDate = destinationAttributes[.modificationDate] as? Date {

                        if sourceDate > destDate {
                            shouldCopy = true
                        }
                    } else {
                        // Konnte Datum nicht lesen → sicherheitshalber NICHT kopieren
                        shouldCopy = false
                    }

                } catch {
                    let errorMessage = String(
                        format: NSLocalizedString("errorComparingFileDates", comment: "Error comparing file dates %@: %@"),
                        file.lastPathComponent,
                        error.localizedDescription
                    )
                    showErrorAlert(errorMessage: errorMessage)
                    success = false
                    shouldCopy = false
                }
            } else {
                // Ziel existiert nicht → kopieren
                shouldCopy = true
            }

            if shouldCopy {
                do {
                    if fileManager.fileExists(atPath: destinationFileURL.path) {
                        try fileManager.removeItem(at: destinationFileURL)
                    }
                    try fileManager.copyItem(at: file, to: destinationFileURL)
                } catch {
                    let errorMessage = String(
                        format: NSLocalizedString("errorCopyingFile", comment: "Error copying file %@: %@"),
                        file.lastPathComponent,
                        error.localizedDescription
                    )
                    showErrorAlert(errorMessage: errorMessage)
                    success = false
                }
            }
        }

    } catch {
        showErrorAlert(errorMessage: NSLocalizedString("errorReadingResources", comment: "Could not read resource directory"))
        return false
    }

    return success
}

