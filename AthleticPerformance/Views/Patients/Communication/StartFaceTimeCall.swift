//
//  StartFaceTimeCall.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.04.25.
//

import Foundation
import UIKit

func startFaceTimeCall(to numberOrEmail: String) {
    guard let url = URL(string: "facetime://\(numberOrEmail)") else { return }
    if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
    } else {
        showErrorAlert(errorMessage: NSLocalizedString("errorFaceTimeNotAvailable", comment: "FaceTime not available"))
    }
}
