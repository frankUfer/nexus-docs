//
//  InsuranceCardScannerView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 02.04.25.
//

import SwiftUI
import Vision
import UIKit

struct InsuranceCardScannerView: View {
    @State private var image: UIImage?
    @State private var showImagePicker = false

    // OCR-Ergebnisse
    @State private var patientName: String = ""
    @State private var birthdate: String = ""
    @State private var insuranceNumber: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Versicherungskarte scannen")) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                    Button("Foto aufnehmen") {
                        showImagePicker = true
                    }
                }

                Section(header: Text("Erkannte Daten (bearbeitbar)")) {
                    ValidatedTextField(title: "Name", text: $patientName, isValid: patientName.isEmpty || patientName.isValidName, errorMessage: "Mindestens Vor- und Nachname erforderlich.")
                    ValidatedTextField(title: "Geburtsdatum", text: $birthdate, isValid: birthdate.isEmpty || birthdate.isValidBirthdate, errorMessage: "Bitte Format TT.MM.JJJJ verwenden.")
                    ValidatedTextField(title: "Versicherungsnummer", text: $insuranceNumber, isValid: insuranceNumber.isEmpty || insuranceNumber.isValidInsuranceNumber, errorMessage: "10 Zeichen, nur Buchstaben/Ziffern.")
                }
            }
            .navigationTitle("Karte scannen")
            .sheet(isPresented: $showImagePicker) {
                PhotoPicker(onImagePicked: { pickedImage in
                    performOCR(on: pickedImage)
                })
            }
        }
    }

    func performOCR(on image: UIImage) {

        guard let cgImage = image.cgImage else {
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let _ = error {
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            let fullText = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")

            extractData(from: fullText)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["de-DE"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {           
            let message = "\(String(format: NSLocalizedString("errorOCR", comment: "Error OCR handler"))): \(error.localizedDescription)"
            showErrorAlert(errorMessage: message)
        }
    }

    func extractData(from text: String) {
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if patientName.isEmpty,
               line.range(of: #"^[A-ZÄÖÜß]+\s+[A-ZÄÖÜß\-]+"#, options: .regularExpression) != nil {
                patientName = line
            }

            if birthdate.isEmpty,
               let match = line.range(of: #"\d{2}\.\d{2}\.\d{4}"#, options: .regularExpression) {
                birthdate = String(line[match])
            }

            if insuranceNumber.isEmpty,
               let match = line.range(of: #"^[A-Z0-9]{10}$"#, options: .regularExpression) {
                insuranceNumber = String(line[match])
            }
        }
    }
}
