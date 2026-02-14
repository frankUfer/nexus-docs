//
//  TreatmentContract.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import Foundation
import UIKit

/// Represents a treatment contract signed by a patient.
struct TreatmentContract {
    /// Information about the medical practice.
    var practice: PracticeInfo

    /// The patient who signed the contract.
    var patient: Patient

    /// The date when the contract was signed.
    var date: Date

    /// The patient's signature as an image.
    var signatureImage: UIImage

    /// The generated text content of the treatment contract.
    var generatedText: String
}

