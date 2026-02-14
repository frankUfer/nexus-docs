//
//  LoadAgreementTextTemplate.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import Foundation
import UIKit

/// Loads the therapy agreement template as an attributed string from the app's resources.
func loadAgreementTextTemplate() -> (success: Bool, template: String?) {
    let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first!
        .appendingPathComponent("resources/templates/therapyAgreement.txt")

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        showErrorAlert(errorMessage: NSLocalizedString("errorAgreementTxtNotFound", comment: "Could not find template for therapy agreement"))
        return (false, nil)
    }

    do {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return (true, text)

    } catch {
        let message = String(format: NSLocalizedString("errorReadingTxt", comment: "Error reading TXT file: %@"), error.localizedDescription)
        showErrorAlert(errorMessage: message)
        return (false, nil)
    }
}
