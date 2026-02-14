//
//  SendEmail.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.04.25.
//

import MessageUI

func sendEmail(to recipient: String, from viewController: UIViewController) {
    if MFMailComposeViewController.canSendMail() {
        let mailVC = MFMailComposeViewController()
        mailVC.setToRecipients([recipient])
        mailVC.setSubject("")
        mailVC.setMessageBody("", isHTML: false)
        mailVC.mailComposeDelegate = viewController as? MFMailComposeViewControllerDelegate
        viewController.present(mailVC, animated: true)
    } else {
        showErrorAlert(errorMessage: NSLocalizedString("errorNoEmailAppAvailable", comment: "No email App Available"))
    }
}
