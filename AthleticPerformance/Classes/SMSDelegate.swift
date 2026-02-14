//
//  SMSDelegate.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.05.25.
//

import MessageUI

final class SMSDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    let onFinish: (MessageComposeResult) -> Void

    init(onFinish: @escaping (MessageComposeResult) -> Void) {
        self.onFinish = onFinish
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                      didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true) {
            self.onFinish(result)
        }
    }
}
