//
//  MailDelegate.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.05.25.
//

import MessageUI

final class MailDelegate: NSObject, MFMailComposeViewControllerDelegate {
    let onFinish: (MFMailComposeResult) -> Void

    init(onFinish: @escaping (MFMailComposeResult) -> Void) {
        self.onFinish = onFinish
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                                didFinishWith result: MFMailComposeResult,
                                error: Error?) {
        controller.dismiss(animated: true) {
            self.onFinish(result)
        }
    }
}
