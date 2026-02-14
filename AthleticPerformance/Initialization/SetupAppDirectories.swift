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
        // RTF → templates (always update when bundle is newer)
        success = success && copyResourcesToParameters(
            destinationURL: documentsURL.appendingPathComponent("resources/templates"),
            withExtensions: ["rtf"],
            seedOnly: false
        )

        // TXT → templates (always update when bundle is newer)
        success = success && copyResourcesToParameters(
            destinationURL: documentsURL.appendingPathComponent("resources/templates"),
            withExtensions: ["txt"],
            seedOnly: false
        )

        // JSON → parameter (seed only: copy if missing, never overwrite)
        success = success && copyResourcesToParameters(
            destinationURL: documentsURL.appendingPathComponent("resources/parameter"),
            withExtensions: ["json"],
            seedOnly: true
        )
    }

    return success
}

func copyResourcesToParameters(destinationURL: URL, withExtensions extensions: [String], seedOnly: Bool = false) -> Bool {
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
                if seedOnly {
                    // Seed-only mode: never overwrite existing files.
                    // Sync will deliver updates from the server.
                    shouldCopy = false
                } else {
                    // Template mode: overwrite when bundle version is newer.
                    do {
                        let sourceAttributes = try fileManager.attributesOfItem(atPath: file.path)
                        let destinationAttributes = try fileManager.attributesOfItem(atPath: destinationFileURL.path)

                        if let sourceDate = sourceAttributes[.modificationDate] as? Date,
                           let destDate = destinationAttributes[.modificationDate] as? Date {
                            shouldCopy = sourceDate > destDate
                        } else {
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
                }
            } else {
                // Destination doesn't exist → copy (both seed and template mode)
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

