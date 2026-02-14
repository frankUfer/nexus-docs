//
//  LoadTreatmentContract.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import Foundation
import UIKit

/// Loads the contract agreement template as an attributed string from the app's resources.
func loadContractTextTemplate() -> (success: Bool, template: String?) {
    let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first!
        .appendingPathComponent("resources/templates/treatmentContract.txt")

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        showErrorAlert(errorMessage: NSLocalizedString("errorTreatmentRtfNotFound", comment: "Could not find template for treatment contract"))
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
