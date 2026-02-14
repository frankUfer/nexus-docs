//
//  MailDelegateWrapper.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.06.25.
//

import MessageUI

final class MailDelegateWrapper: NSObject, MFMailComposeViewControllerDelegate {
    private let onResult: (MFMailComposeResult) -> Void

    init(onResult: @escaping (MFMailComposeResult) -> Void) {
        self.onResult = onResult
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true) {
            self.onResult(result)
        }
    }
}
