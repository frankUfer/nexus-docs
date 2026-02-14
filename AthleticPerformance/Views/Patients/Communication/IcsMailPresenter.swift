//
//  IcsMailPresenter.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.06.25.
//

import UIKit
import MessageUI

enum IcsMailPresenter {
    private static var currentDelegate: MailDelegateWrapper?

    // Bestehende Funktion bleibt unverändert

    static func presentMail(
        recipient: String,
        subject: String,
        message: String,
        attachments: [(filename: String, data: Data)],
        sender: String,
        onResult: @escaping (MFMailComposeResult) -> Void
    ) {
        guard MFMailComposeViewController.canSendMail() else {
            showErrorAlert(errorMessage: NSLocalizedString("errorNoEmailAppAvailable", comment: "Error no email app available"))
            onResult(.failed)
            return
        }

        let mail = MFMailComposeViewController()
        mail.setToRecipients([recipient])
        mail.setSubject(subject)
        mail.setMessageBody(message, isHTML: false)

        for attachment in attachments {
            mail.addAttachmentData(
                attachment.data,
                mimeType: "text/calendar; method=REQUEST; charset=UTF-8",
                fileName: attachment.filename
            )
        }

        let delegate = MailDelegateWrapper(onResult: { result in
            onResult(result)
            currentDelegate = nil
        })

        mail.mailComposeDelegate = delegate
        currentDelegate = delegate

        if let topController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController {
            topController.present(mail, animated: true)
        } else {
            showErrorAlert(errorMessage: NSLocalizedString("errorNoRootViewController", comment: "Error no email app available"))
            onResult(.failed)
        }
    }
}
