//
//  AgreementThumbnailView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import SwiftUI
import MessageUI
import PDFKit
import ZipArchive

struct AgreementThumbnailView: View {
    let fileURL: URL
    let patient: Patient
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var mailStatusMessage: String?
    @State private var showMailStatus = false
    
    @Binding var selectedEmail: String?
    @Binding var showMailComposer: Bool
    @Binding var showEmailSelectionSheet: Bool
    @Binding var encryptedPDFURL: URL?
    @Binding var emailPassword: String?
    @State private var emailSelectionAction: (() -> Void)? = nil
    @State private var retainedMailDelegate: MailDelegate? = nil
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var retainedSMSDelegate: SMSDelegate? = nil

    var body: some View {
        HStack {
            if let pdf = PDFDocument(url: fileURL), let page = pdf.page(at: 0) {
                let thumbnail = page.thumbnail(of: CGSize(width: 100, height: 140), for: .cropBox)
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 140)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .contextMenu {
                        Button { sendEmail(with: fileURL, for: patient) } label: {
                            Label(NSLocalizedString("email", comment: "eMail"), systemImage: "envelope")
                        }
                        Button { printPDF(from: fileURL) } label: {
                            Label(NSLocalizedString("print", comment: "Print"), systemImage: "printer")
                        }
//                        Button(role: .destructive) {
//                            showDeleteConfirmation = true
//                        } label: {
//                            Label(NSLocalizedString("delete", comment: "Delete"), systemImage: "trash")
//                        }
                    }
                    .onTapGesture {
                        onTap()
                    }
//                    .alert(NSLocalizedString("deleteAgreement", comment: "Delete agreement"), isPresented: $showDeleteConfirmation) {
//                        Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
//                            try? FileManager.default.removeItem(at: fileURL)
//                            onDelete()
//                        }
//                        Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
//                    } message: {
//                        Text(NSLocalizedString("reallyDeleteAgreement", comment: "Really delete agreement?"))
//                    }
            }
        }
        if showToast {
               ToastView(message: toastMessage)
                   .zIndex(1)
                   .onAppear {
                       DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                           withAnimation {
                               showToast = false
                           }
                       }
                   }
           }
    }
    
    
    private func sendEmail(with originalURL: URL, for patient: Patient) {
        guard !patient.emailAddresses.isEmpty else {
            showErrorAlert(errorMessage: NSLocalizedString("noEmailFound", comment: "No email found"))
            return
        }

        let localizedName = NSLocalizedString("agreementFilename", comment: "Agreement filename")
        let filename = "\(localizedName)_\(patient.firstname.replacingOccurrences(of: " ", with: "_"))_\(patient.lastname.replacingOccurrences(of: " ", with: "_")).pdf"

        let password = generatePassword()

        // Neue ZIP-Datei mit dem neuen Namen
        let zipFilename = filename.replacingOccurrences(of: ".pdf", with: ".zip")
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(zipFilename)

        // PDF-Datei ggf. umbenennen (Kopie im Temp-Ordner)
        let renamedPDFURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: renamedPDFURL.path) {
                try FileManager.default.removeItem(at: renamedPDFURL)
            }
            try FileManager.default.copyItem(at: originalURL, to: renamedPDFURL)
        } catch {
            showErrorAlert(errorMessage: NSLocalizedString("copyFailed", comment: "Could not copy file"))
            return
        }

        // ZIP erzeugen
        let zipSuccess = SSZipArchive.createZipFile(atPath: zipURL.path,
                                                     withFilesAtPaths: [renamedPDFURL.path],
                                                     withPassword: password)

        guard zipSuccess else {
            showErrorAlert(errorMessage: NSLocalizedString("zipFailed", comment: "ZIP creation failed"))
            return
        }

        func presentMailComposer(to recipient: String) {
            guard MFMailComposeViewController.canSendMail() else {
                showErrorAlert(errorMessage: NSLocalizedString("mailUnavailable", comment: "Mail unavailable"))
                return
            }
            
            let subject = patient.firstnameTerms
                    ? NSLocalizedString("agreementSubjectFirstnameTerms", comment: "")
                    : NSLocalizedString("agreementSubject", comment: "")

            let introductoryText = patient.firstnameTerms
                    ? NSLocalizedString("introText1FirstnameTerms", comment: "") + patient.firstname
                    : NSLocalizedString("introText1", comment: "") + patient.fullName
            
            let agreementBody = patient.firstnameTerms
                    ? NSLocalizedString("agreementBodyFirstnameTerms", comment: "")
                    : NSLocalizedString("agreementBody", comment: "")
                    
            let passwordNote = patient.firstnameTerms
                    ? NSLocalizedString("passwordNoteFirstnameTerms", comment: "")
                    : NSLocalizedString("passwordNote", comment: "")
            
            let mailVC = MFMailComposeViewController()
            mailVC.setToRecipients([recipient])
            mailVC.setSubject("\(subject) \(AppGlobals.shared.practiceInfo.name)")
            let mailDelegate = MailDelegate { result in
                try? FileManager.default.removeItem(at: zipURL)
                try? FileManager.default.removeItem(at: renamedPDFURL)

                switch result {
                case .sent:
                    toastMessage = NSLocalizedString("mailSent", comment: "Mail sent")

                    // 👉 SMS nur bei erfolgreichem Versand
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if patient.phoneNumbers.count == 1 {
                            presentSMSComposer(to: patient.phoneNumbers[0].value, password: password)
                        } else if patient.phoneNumbers.count > 1 {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = scene.windows.first?.rootViewController {
                                
                                let alert = UIAlertController(
                                    title: NSLocalizedString("choosePhone", comment: "Choose Phone"),
                                    message: nil,
                                    preferredStyle: .actionSheet
                                )

                                for entry in patient.phoneNumbers {
                                    alert.addAction(UIAlertAction(
                                        title: "\(NSLocalizedString(entry.label, comment: "")): \(entry.value)",
                                        style: .default
                                    ) { _ in
                                        presentSMSComposer(to: entry.value, password: password)
                                    })
                                }

                                alert.addAction(UIAlertAction(
                                    title: NSLocalizedString("cancel", comment: "Cancel"),
                                    style: .cancel
                                ))

                                // ✅ iPad-Popover absichern
                                if let popover = alert.popoverPresentationController {
                                    popover.sourceView = rootVC.view
                                    popover.sourceRect = CGRect(
                                        x: rootVC.view.bounds.midX,
                                        y: rootVC.view.bounds.midY,
                                        width: 0,
                                        height: 0
                                    )
                                    popover.permittedArrowDirections = []
                                }

                                rootVC.present(alert, animated: true)
                            }
                        }
                    }

                case .cancelled:
                    toastMessage = NSLocalizedString("mailCancelled", comment: "Mail cancelled")
                case .saved:
                    toastMessage = NSLocalizedString("mailSaved", comment: "Mail saved")
                case .failed:
                    toastMessage = NSLocalizedString("mailFailed", comment: "Mail failed")
                @unknown default:
                    toastMessage = NSLocalizedString("mailUnknown", comment: "Unknown result")
                }

                withAnimation {
                    showToast = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showToast = false
                        toastMessage = ""
                    }
                }

                retainedMailDelegate = nil
            }
            retainedMailDelegate = mailDelegate
            mailVC.mailComposeDelegate = mailDelegate

            // let practiceName = AppGlobals.shared.practiceInfo.name
            let message = """
            \(introductoryText),

            \(agreementBody)
            
            \(passwordNote)

            """
//            \(NSLocalizedString("manyGreetings", comment: "Many greetings")),
//            \(practiceName)
//            """

            mailVC.setMessageBody(message, isHTML: false)

            if let zipData = try? Data(contentsOf: zipURL) {
                mailVC.addAttachmentData(zipData, mimeType: "application/zip", fileName: zipFilename)
            }

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                rootVC.present(mailVC, animated: true, completion: nil)
            }
        }

        if patient.emailAddresses.count == 1 {
            // Direkt senden
            presentMailComposer(to: patient.emailAddresses[0].value)
        } else {
            // Mehrere Optionen → UIAlertController anzeigen
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                let alert = UIAlertController(title: NSLocalizedString("chooseEmail", comment: "Choose Email"), message: nil, preferredStyle: .actionSheet)
                
                for entry in patient.emailAddresses {
                    alert.addAction(UIAlertAction(title: "\(NSLocalizedString(entry.label, comment: "")): \(entry.value)", style: .default) { _ in
                        presentMailComposer(to: entry.value)
                    })
                }
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel))
                
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func printPDF(from url: URL) {
        guard let pdfData = PDFDocument(url: url)?.dataRepresentation() else {
            showErrorAlert(errorMessage: NSLocalizedString("errorLoadingPDF", comment: "Error loading PDF."))
            return
        }

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = url.lastPathComponent
        printInfo.orientation = .portrait
        printInfo.duplex = .longEdge

        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = pdfData

        // iPad: Präsentation im aktuellen View-Kontext
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            printController.present(from: rootVC.view.frame, in: rootVC.view, animated: true, completionHandler: nil)
        } else {
            // Fallback für andere Geräte (z. B. iPhone)
            printController.present(animated: true, completionHandler: nil)
        }
    }
    
    private func generatePassword(length: Int = 16) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#!$-%&*()_+"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
    
    func presentSMSComposer(to phoneNumber: String, password: String) {
        guard MFMessageComposeViewController.canSendText() else {
            showErrorAlert(errorMessage: NSLocalizedString("smsUnavailable", comment: "SMS not available"))
            return
        }

        let smsVC = MFMessageComposeViewController()
        smsVC.recipients = [phoneNumber]
        smsVC.body = password

        let smsDelegate = SMSDelegate {
            switch $0 {
            case .sent:
                toastMessage = NSLocalizedString("smsSent", comment: "SMS sent")
            case .cancelled:
                toastMessage = NSLocalizedString("smsCancelled", comment: "SMS cancelled")
            case .failed:
                toastMessage = NSLocalizedString("smsFailed", comment: "SMS failed")
            @unknown default:
                toastMessage = NSLocalizedString("smsUnknown", comment: "Unknown SMS result")
            }

            withAnimation {
                showToast = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showToast = false
                    toastMessage = ""
                }
            }

            retainedSMSDelegate = nil
        }

        retainedSMSDelegate = smsDelegate
        smsVC.messageComposeDelegate = smsDelegate

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(smsVC, animated: true)
        }
    }
}
