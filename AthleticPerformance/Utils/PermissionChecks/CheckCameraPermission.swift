//
//  checkCameraPermission.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 02.04.25.
//

import AVFoundation

func checkCameraPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        return
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
            } else {
                showErrorAlert(errorMessage: NSLocalizedString("errorCameraAccessDenied", comment: "Error camera access denied"))
            }
        }
    case .denied, .restricted:
        showErrorAlert(errorMessage: NSLocalizedString("errorCameraAccessDeniedChangeSettings", comment: "Error camera access denied. Please change settings."))
    @unknown default:
        break
    }
}
