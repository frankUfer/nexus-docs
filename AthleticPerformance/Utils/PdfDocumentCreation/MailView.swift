//
//  MailView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import SwiftUI
import MessageUI

struct MailView: UIViewControllerRepresentable {
    var recipient: String
    var subject: String
    var message: String
    var attachmentURL: URL
    var sender: String
    var onResult: () -> Void
    @Binding var statusMessage: String?

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView

        init(parent: MailView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            switch result {
            case .sent:
                parent.statusMessage = NSLocalizedString("mailSent", comment: "Mail sent successfully")
            case .saved:
                parent.statusMessage = NSLocalizedString("mailSaved", comment: "Mail saved to drafts")
            case .cancelled:
                parent.statusMessage = NSLocalizedString("mailCancelled", comment: "Mail sending cancelled")
            case .failed:
                parent.statusMessage = NSLocalizedString("mailFailed", comment: "Mail sending failed")
            @unknown default:
                parent.statusMessage = NSLocalizedString("mailUnknown", comment: "Unknown mail result")
            }

            controller.dismiss(animated: true)
            parent.onResult()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.setToRecipients([recipient])
        mail.setSubject(subject)
        mail.setMessageBody(message, isHTML: false)

        if let data = try? Data(contentsOf: attachmentURL) {
            mail.addAttachmentData(data, mimeType: "application/pdf", fileName: attachmentURL.lastPathComponent)
        }

        mail.mailComposeDelegate = context.coordinator
        return mail
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
