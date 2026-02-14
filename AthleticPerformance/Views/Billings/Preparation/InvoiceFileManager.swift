//
//  LoadInvoicePDFMediaFiles.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 24.06.25.
//

import Foundation

struct InvoiceFileManager {

    // MARK: - PDF Media Dateien laden

    enum InvoiceFileError: Error {
        case patientDirectoryReadFailed
        case invoiceDirectoryReadFailed
    }

    static func loadInvoicePDFMediaFiles() -> [MediaFile] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let patientsDir = documentsURL.appendingPathComponent("patients")

        var mediaFiles: [MediaFile] = []

        do {
            let patientDirs = try fileManager.contentsOfDirectory(
                at: patientsDir,
                includingPropertiesForKeys: nil
            )

            for patientDir in patientDirs {
                let patientId = patientDir.lastPathComponent
                let invoiceDir = patientDir.appendingPathComponent("invoices")

                var isDirectory: ObjCBool = false
                guard
                    fileManager.fileExists(
                        atPath: invoiceDir.path,
                        isDirectory: &isDirectory
                    ), isDirectory.boolValue
                else {
                    continue
                }

                do {
                    let files = try fileManager.contentsOfDirectory(
                        at: invoiceDir,
                        includingPropertiesForKeys: [.creationDateKey]
                    )

                    for file in files
                    where file.pathExtension.lowercased() == "pdf" {
                        let date =
                            (try? file.resourceValues(forKeys: [
                                .creationDateKey
                            ]))?.creationDate ?? Date()
                        let relativePath =
                            "patients/\(patientId)/invoices/\(file.lastPathComponent)"

                        let media = MediaFile(
                            id: UUID(),
                            filename: file.lastPathComponent,
                            date: date,
                            relativePath: relativePath
                        )
                        mediaFiles.append(media)
                    }

                } catch {
                    throw ErrorType.patientDirectoryReadFailed
                }
            }

        } catch let error as ErrorType {
            let errorMessage: String

            switch error {
            case .patientDirectoryReadFailed:
                errorMessage = NSLocalizedString(
                    "invoiceLoadPatientsDirError",
                    comment: ""
                )
            case .invoiceDirectoryReadFailed:
                errorMessage = NSLocalizedString(
                    "invoiceLoadInvoicesDirError",
                    comment: ""
                )
            case .decodingFailed:
                errorMessage = NSLocalizedString(
                    "invoiceLoadDecodingError",
                    comment: ""
                )
            default:
                errorMessage = NSLocalizedString(
                    "invoiceLoadUnknownError",
                    comment: ""
                )
            }

            showErrorAlert(errorMessage: errorMessage)

        } catch {
            // Fallback, falls was anderes schiefgeht
            let errorMessage = NSLocalizedString(
                "invoiceLoadUnknownError",
                comment: ""
            )
            showErrorAlert(errorMessage: errorMessage)
        }

        return mediaFiles
    }

    // MARK: - PDF speichern

    static func saveInvoicePDF(
        data: Data,
        for invoice: Invoice,
        usingNumber number: String
    ) {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let pdfURL =
            documentsURL
            .appendingPathComponent("patients")
            .appendingPathComponent(invoice.patientId.uuidString)
            .appendingPathComponent("invoices")
            .appendingPathComponent("\(number).pdf")

        let directoryURL = pdfURL.deletingLastPathComponent()

        do {
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                do {
                    try FileManager.default.createDirectory(
                        at: directoryURL,
                        withIntermediateDirectories: true
                    )
                } catch {
                    throw ErrorType.directoryCreationFailed
                }
            }

            do {
                try data.write(to: pdfURL, options: .atomic)
            } catch {
                throw ErrorType.writeFailed
            }

        } catch {
            var errorMessage: String

            switch error {
            case ErrorType.directoryCreationFailed:
                errorMessage = NSLocalizedString(
                    "invoiceSaveDiskError",
                    comment: ""
                )
            case ErrorType.writeFailed:
                errorMessage = NSLocalizedString(
                    "invoiceSaveDiskError",
                    comment: ""
                )
            default:
                errorMessage = NSLocalizedString(
                    "invoiceSaveUnknownError",
                    comment: ""
                )
            }

            showErrorAlert(errorMessage: errorMessage)
        }
    }

    // MARK: - Nicht gesandte Rechnungen laden

    static func loadUnsentInvoices() -> [Invoice] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let patientsDir = documentsURL.appendingPathComponent("patients")

        var unsentInvoices: [Invoice] = []

        if let patientDirs = try? fileManager.contentsOfDirectory(
            at: patientsDir,
            includingPropertiesForKeys: nil
        ) {
            for patientDir in patientDirs {
                let invoiceDir = patientDir.appendingPathComponent("invoices")
                if let files = try? fileManager.contentsOfDirectory(
                    at: invoiceDir,
                    includingPropertiesForKeys: nil
                ) {
                    for file in files
                    where file.pathExtension.lowercased() == "json" {
                        if let data = try? Data(contentsOf: file),
                            let invoice = try? JSONDecoder().decode(
                                Invoice.self,
                                from: data
                            )
                        {
                            if invoice.isCreated && (invoice.isSent != true) {
                                unsentInvoices.append(invoice)
                            }
                        }
                    }
                }
            }
        }

        return unsentInvoices
    }

    // MARK: - Rechnungs-JSONs laden (optional nach PatientId)

    static func loadInvoices(for patientId: UUID? = nil) -> [Invoice] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let patientsDir = documentsURL.appendingPathComponent("patients")

        var invoices: [Invoice] = []

        do {
            let patientDirs = try fileManager.contentsOfDirectory(
                at: patientsDir,
                includingPropertiesForKeys: nil
            )

            for patientDir in patientDirs {
                let thisPatientId = patientDir.lastPathComponent

                // 👉 Filter aktiv → nur passenden Ordner verarbeiten
                if let filterId = patientId,
                    filterId.uuidString != thisPatientId
                {
                    continue
                }

                let invoiceDir = patientDir.appendingPathComponent("invoices")

                do {
                    let files = try fileManager.contentsOfDirectory(
                        at: invoiceDir,
                        includingPropertiesForKeys: nil
                    )

                    for file in files
                    where file.pathExtension.lowercased() == "json" {
                        do {
                            let data = try Data(contentsOf: file)
                            let invoice = try JSONDecoder().decode(
                                Invoice.self,
                                from: data
                            )
                            invoices.append(invoice)
                        } catch {
                            let errorMessage = NSLocalizedString(
                                "invoiceLoadUnknownError",
                                comment: ""
                            )
                            showErrorAlert(errorMessage: errorMessage)
                        }
                    }

                } catch {
                    throw ErrorType.invoiceDirectoryReadFailed
                }
            }

        } catch let error as ErrorType {
            let errorMessage: String

            switch error {
            case .patientDirectoryReadFailed:
                errorMessage = NSLocalizedString(
                    "invoiceLoadPatientsDirError",
                    comment: ""
                )
            case .invoiceDirectoryReadFailed:
                errorMessage = NSLocalizedString(
                    "invoiceLoadInvoicesDirError",
                    comment: ""
                )
            case .decodingFailed:
                errorMessage = NSLocalizedString(
                    "invoiceLoadDecodingError",
                    comment: ""
                )
            default:
                errorMessage = NSLocalizedString(
                    "invoiceLoadUnknownError",
                    comment: ""
                )
            }

            showErrorAlert(errorMessage: errorMessage)

        } catch {
            // Fallback, falls was anderes schiefgeht
            let errorMessage = NSLocalizedString(
                "invoiceLoadUnknownError",
                comment: ""
            )
            showErrorAlert(errorMessage: errorMessage)
        }

        return invoices
    }

    // MARK: - Eine Invoice speichern (JSON)

    static func saveInvoice(_ invoice: Invoice) {
        let fileManager = FileManager.default
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let patientDir =
            documentsURL
            .appendingPathComponent("patients")
            .appendingPathComponent(invoice.patientId.uuidString)
            .appendingPathComponent("invoices")

        do {
            try fileManager.createDirectory(
                at: patientDir,
                withIntermediateDirectories: true
            )

            let fileURL = patientDir.appendingPathComponent(
                "\(invoice.invoiceNumber).json"
            )
            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(invoice)
            } catch {
                throw ErrorType.encodingFailed
            }

            do {
                try jsonData.write(to: fileURL, options: .atomic)
            } catch {
                throw ErrorType.writeFailed
            }

        } catch {
            var errorMessage: String

            switch error {
            case ErrorType.encodingFailed:
                errorMessage = NSLocalizedString(
                    "invoiceSaveEncodingError",
                    comment: ""
                )
            case ErrorType.writeFailed:
                errorMessage = NSLocalizedString(
                    "invoiceSaveDiskError",
                    comment: ""
                )
            default:
                errorMessage = NSLocalizedString(
                    "invoiceSaveUnknownError",
                    comment: ""
                )
            }

            showErrorAlert(errorMessage: errorMessage)
        }
    }

    static func extractInvoiceNumber(from filename: String) -> Int {
        let base = filename.replacingOccurrences(of: ".pdf", with: "")
        return Int(base) ?? 0
    }

    static func groupMediaFilesByPatient(_ files: [MediaFile]) -> [UUID:
        [MediaFile]]
    {
        Dictionary(grouping: files) { file -> UUID in
            let parts = file.relativePath.split(separator: "/")
            if parts.count >= 2, let uuid = UUID(uuidString: String(parts[1])) {
                return uuid
            }
            return UUID()  // Fallback Dummy
        }
    }

    static func markInvoiceAsSent(invoiceNumber: String, patientId: UUID) {
        // 1️⃣ JSON-Datei finden
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let fileURL =
            documentsURL
            .appendingPathComponent("patients")
            .appendingPathComponent(patientId.uuidString)
            .appendingPathComponent("invoices")
            .appendingPathComponent("\(invoiceNumber).json")

        do {
            // 2️⃣ Vorhandene Invoice laden
            let data = try Data(contentsOf: fileURL)
            var invoice = try JSONDecoder().decode(Invoice.self, from: data)

            // 3️⃣ Status ändern
            invoice.isSent = true

            // 4️⃣ Wieder speichern
            saveInvoice(invoice)

        } catch {
            showErrorAlert(
                errorMessage: NSLocalizedString(
                    "invoiceSaveUnknownError",
                    comment: ""
                )
            )
        }
    }

    // MARK: - Storno
    /// Markiert die Original-Rechnung als storniert
    static func markInvoiceAsReversed(
        _ invoice: Invoice,
        reversalNumber: String
    ) throws {
        var updatedInvoice = invoice
        updatedInvoice.reversalNumber = reversalNumber
        updatedInvoice.isReversed = true

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let patientDir =
            documentsURL
            .appendingPathComponent("patients")
            .appendingPathComponent(invoice.patientId.uuidString)
            .appendingPathComponent("invoices")

        let originalJSONURL = patientDir.appendingPathComponent(
            "\(invoice.invoiceNumber).json"
        )
        let jsonData = try JSONEncoder().encode(updatedInvoice)
        try jsonData.write(to: originalJSONURL, options: .atomic)
    }

    /// Setzt Sessions zurück und gibt den zugehörigen TherapyPlan zurück
    @MainActor
    static func resetSessionsAfterReversal(
        invoice: Invoice,
        in patientStore: PatientStore
    ) throws -> UUID {
        guard
            var patient = patientStore.patients.first(where: {
                $0.id == invoice.patientId
            })
        else {
            throw NSError(
                domain: "cancelInvoice",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Patient nicht gefunden"]
            )
        }

        let sessionIDs = invoice.items.compactMap {
            UUID(uuidString: $0.sessionId)
        }

        for therapyIndex in patient.therapies.indices {
            guard var therapy = patient.therapies[therapyIndex] else {
                continue
            }

            for planIndex in therapy.therapyPlans.indices {
                for sessionIndex in therapy.therapyPlans[planIndex]
                    .treatmentSessions.indices
                {
                    var session = therapy.therapyPlans[planIndex]
                        .treatmentSessions[sessionIndex]
                    if sessionIDs.contains(session.id) {
                        session.isInvoiced = false
                        session.isDone = true
                        therapy.therapyPlans[planIndex].treatmentSessions[
                            sessionIndex
                        ] = session
                    }
                }
            }

            patient.therapies[therapyIndex] = therapy
        }

        let firstSessionID = invoice.items.first.flatMap {
            UUID(uuidString: $0.sessionId)
        }

        var therapyPlanId: UUID? = nil
        for therapy in patient.therapies.compactMap({ $0 }) {
            for plan in therapy.therapyPlans {
                if plan.treatmentSessions.contains(where: {
                    $0.id == firstSessionID
                }) {
                    therapyPlanId = plan.id
                    break
                }
            }
            if therapyPlanId != nil { break }
        }
        guard let planId = therapyPlanId else {
            throw NSError(
                domain: "cancelInvoice",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "TherapyPlan nicht gefunden"
                ]
            )
        }

        patientStore.updatePatient(patient)
        return planId
    }

}
