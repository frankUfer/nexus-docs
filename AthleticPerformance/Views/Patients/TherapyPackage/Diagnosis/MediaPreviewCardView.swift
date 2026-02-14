//
//  MediaPreviewCardView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.04.25.
//

import SwiftUI
import AVKit
import PDFKit
import UIKit

struct MediaPreviewCardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var patientStore: PatientStore
    
    let media: MediaFile
    @Binding var mediaFiles: [MediaFile]
    @Binding var diagnosis: Diagnosis
    let selectedPatientId: UUID
    let therapyId: UUID
    var onChange: (() -> Void)? = nil
    
    @State private var showFullscreen = false
    @State private var showDeleteConfirm = false
    @State private var extractedText: String?
    @State private var showImportResult = false
    @State private var showClipboardSuccess = false
    @State private var showClipboardError = false
    @State private var showPatientMismatchError = false
    @State private var showImportConfirmation = false
    
    @State private var extractedDiagnosis: DiagnosisInfo?
    @State private var extractedRemedies: [Remedy] = []
    @State private var extractedDoctor: DiagnosisSource?
    @State private var patientMatchPercentage: Int = 0
    @State private var rotatedImage: UIImage? = nil
       
    var selectedPatient: Patient? {
        patientStore.patients.first(where: { $0.id == selectedPatientId })
    }
    
    private var fileURL: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent(media.relativePath)
    }
    
    private var isTherapyPlanCompleted: Bool {
        selectedPatient?.therapies
            .compactMap { $0 }
            .first(where: { $0.id == therapyId })?
            .therapyPlans
            .first(where: { $0.diagnosisId == diagnosis.id })?
            .isCompleted ?? false
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        showFullscreen = true
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .padding(8)
                            .background(Color.mediaButton.opacity(0.6))
                            .clipShape(Circle())
                            .foregroundColor(.icon)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Button für das Kopieren des extrahierten Textes
                    if media.fileType == .image || media.fileType == .pdf {
                        
                        Button(action: {
                            extractTextForClipboard(from: fileURL)
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .padding(8)
                                .font(.system(size: 15, weight: .thin))
                                .foregroundColor(.icon)
                                .background(Color.mediaButton.opacity(0.6))
                                .clipShape(Circle())
                        }
                        Spacer()
                        
                        if media.fileType == .image {
                            Button(action: {
                                rotateImageAndSave(fileURL: fileURL)
                            }) {
                                Image(systemName: "rotate.right")
                                    .padding(8)
                                    .font(.system(size: 15, weight: .thin))
                                    .foregroundColor(.icon)
                                    .background(Color.mediaButton.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        
                        // Button für das Extrahieren und Importieren des Rezepts                        
                        if !isTherapyPlanCompleted {
                        Button(action: {
                            extractTextAndImport(from: fileURL)
                            }) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .padding(8)
                                    .font(.system(size: 15, weight: .thin))
                                    .foregroundColor(.icon)
                                    .background(Color.mediaButton.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .thin))
                            .padding(8)
                            .background(Color.mediaButton.opacity(0.6))
                            .clipShape(Circle())
                            .foregroundColor(.icon)
                    }
                    .padding(.horizontal, 12)
                }
                
                ZStack {
                    previewContent
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                        .frame(maxHeight: .infinity)
                }
                
                HStack {
                    Spacer()
                    
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .thin))
                            .padding(8)
                            .background(Color.deleteButton.opacity(0.6))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .presentationDetents([.large])
            .fullScreenCover(isPresented: $showFullscreen) {
                MediaPreviewView(media: media)
            }
            .confirmationDialog(NSLocalizedString("reallyDeleteMedia", comment: "Add Diagnosis"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                    deleteMedia()
                }
                Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
            }
            .sheet(isPresented: $showImportConfirmation) {
                RecipeImportConfirmationView(
                    diagnosis: extractedDiagnosis,
                    remedies: extractedRemedies,
                    doctor: extractedDoctor,
                    matchPercentage: patientMatchPercentage,
                    onConfirm: handleImportConfirmed,
                    onCancel: { showImportConfirmation = false }
                )
            }
            
            if showClipboardSuccess {
                Text(NSLocalizedString("recognizedText", comment: "Text recognized and copied"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.positiveCheck.opacity(0.95))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
            
            if showClipboardError {
                Text(NSLocalizedString("noTextDetection", comment: "No text detected"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.deleteButton.opacity(0.95))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
            
            if showPatientMismatchError {
                Text(NSLocalizedString("patientMismatch", comment: "The patient data in the prescription does not match the selected patient."))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.deleteButton.opacity(0.95))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut, value: showClipboardSuccess || showClipboardError)
    }
    
    private func deleteMedia() {
        if let index = mediaFiles.firstIndex(of: media) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                let message = String(format: NSLocalizedString("errorDeletingFile", comment: "Error deleting file: %@"), error.localizedDescription)
                showErrorAlert(errorMessage: message)
            }
            mediaFiles.remove(at: index)
            onChange?() 
            dismiss()
        }
    }
    
    @ViewBuilder
    private var previewContent: some View {
        switch media.fileType {
        case .image:
            if let image = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .background(Color.black)
            } else {
                Text(NSLocalizedString("imageNotLoaded", comment: "Image could not be loaded"))
                    .foregroundColor(.white)
            }
        case .video:
            VideoPlayer(player: AVPlayer(url: fileURL))
        case .pdf:
            PDFKitView(url: fileURL)
        case .csv:
            if let table = CSVTable(from: fileURL) {
                let widths = calculateColumnWidths(for: table, fontSize: 8)
                CSVPreviewMiniView(table: table, columnWidths: widths, fontSize: 8)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text(NSLocalizedString("errorCSVLoading", comment: "CSV file could not be loaded."))
            }
        default:
            Text(NSLocalizedString("noPreviewAvailable", comment: "Preview not available."))
        }
    }
    
    /// Nur Text extrahieren und in Zwischenablage speichern
    private func extractTextForClipboard(from fileURL: URL) {
        extractText(from: fileURL) { text in
            extractedText = text
            
            if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UIPasteboard.general.string = text
                showClipboardSuccess = true
                // Automatisch ausblenden nach 2 Sekunden
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showClipboardSuccess = false
                    }
                }
            } else {
                showClipboardError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showClipboardError = false
                    }
                }
            }
        }
    }
    
    /// Text extrahieren und danach automatisch RecipeImporter starten
    private func extractTextAndImport(from fileURL: URL) {
        extractText(from: fileURL) { text in
            guard let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            performRecipeImport(with: text)
        }
    }
    
    /// Funktion für allgemeine Textextraktion
    private func extractText(from fileURL: URL, completion: @escaping (String?) -> Void) {
        if fileURL.pathExtension.lowercased() == "pdf" {
            extractTextFromPDF(pdfURL: fileURL, completion: completion)
        } else if ["jpg", "jpeg", "png", "tiff"].contains(fileURL.pathExtension.lowercased()) {
            extractTextFromImage(imageURL: fileURL, completion: completion)
        } else {
            completion(NSLocalizedString("unsupportedFileTypeForTextExtraction", comment: "Unsupported file type for text extraction."))
        }
    }
    
    private func extractTextFromPDF(pdfURL: URL, completion: @escaping (String?) -> Void) {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            completion(nil)
            return
        }
        
        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                text += page.string ?? ""
            }
        }
        completion(text)
    }
    
    private func performRecipeImport(with ocrText: String) {
        let textProcessor = OCRTextProcessor()
        var currentOCRLines = textProcessor.preprocess(text: ocrText)
        
        // --- Patientendaten extrahieren ---
        let matcher = PatientOCRMatcher()
        guard let selectedPatient = selectedPatient else {
            return
        }

        let patientMatchResult = matcher.match(patient: selectedPatient, in: currentOCRLines)
        
        if patientMatchResult.matchPercentage == 0 {
            // Fehleranzeige auslösen und abbrechen
            showPatientMismatchError = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showPatientMismatchError = false
            }
            return
        }
        
        patientMatchPercentage = patientMatchResult.matchPercentage
        currentOCRLines = patientMatchResult.cleanedOCRLines

        // --- Diagnose extrahieren ---
        let diagnosisResult = extractDiagnosisInfoAndClean(from: currentOCRLines)
        extractedDiagnosis = diagnosisResult.diagnosis
        currentOCRLines = diagnosisResult.cleanedLines

        // --- Arztinformationen extrahieren ---
        let doctorResult = extractDoctorInfoAndClean(from: currentOCRLines)
        extractedDoctor = doctorResult.doctor
        currentOCRLines = doctorResult.cleanedLines
        
        // --- Heilmittel extrahieren ---
        let remedyResult = extractRemedies(from: currentOCRLines)
        extractedRemedies = remedyResult.remedies
        currentOCRLines = remedyResult.cleanedLines
        
        // Öffne Bestätigungsdialog
        showImportConfirmation = true
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
    private func handleImportConfirmed() {
        guard let diagnosisId = media.linkedDiagnosisId else { return }
        guard let patient = selectedPatient else { return }

        // Therapie/Diagnose lok al updaten
        guard let therapyIndex = patient.therapies.firstIndex(where: { $0?.id == therapyId }),
              let therapy = patient.therapies[therapyIndex],
              let diagnosisIndex = therapy.diagnoses.firstIndex(where: { $0.id == diagnosisId })
        else { return }

        let updatedDiagnosisInfo = extractedDiagnosis ?? DiagnosisInfo(text: "", diagnosisDate: nil)
        let updatedDoctor = extractedDoctor ?? DiagnosisSource()

        let treatments = extractedRemedies.map { remedy in
            let matched = matchTreatmentService(for: remedy.name)
            return DiagnosisTreatments(
                id: UUID(),
                number: Int(remedy.quantity) ?? 10,
                description: remedy.name,
                treatmentService: matched?.internalId
            )
        }

        var updatedDiagnosis = therapy.diagnoses[diagnosisIndex]
        updatedDiagnosis.title = updatedDiagnosisInfo.text
        updatedDiagnosis.date = updatedDiagnosisInfo.diagnosisDate ?? Date()
        updatedDiagnosis.source = DiagnosisSource(
            originName: updatedDoctor.originName,
            street: updatedDoctor.street,
            postalCode: updatedDoctor.postalCode,
            city: updatedDoctor.city,
            phoneNumber: updatedDoctor.phoneNumber,
            specialty: updatedDoctor.specialty,
            createdAt: updatedDiagnosisInfo.diagnosisDate ?? Date()
        )
        updatedDiagnosis.treatments = treatments
        updatedDiagnosis.notes = therapy.diagnoses[diagnosisIndex].notes

        // ⬇️ Nur Bindings updaten (damit UI sofort zeigt)
        DispatchQueue.main.async {
            if let idx = mediaFiles.firstIndex(of: media) {
                mediaFiles[idx].linkedDiagnosisId = diagnosisId
            }
            diagnosis = updatedDiagnosis
            onChange?()     // ⬅️ „dirty“ markieren, Persist passiert oben
        }

        showImportConfirmation = false
        dismiss()
    }
    
    private func rotateImageAndSave(fileURL: URL) {
        guard let image = UIImage(contentsOfFile: fileURL.path) else { return }
        guard let rotated = image.rotated90DegreesClockwise() else { return }
        guard let data = rotated.jpegData(compressionQuality: 1.0) else { return }

        try? data.write(to: fileURL, options: .atomic)
        rotatedImage = rotated
    }
    
    private func matchTreatmentService(for remedyName: String) -> TreatmentService? {
        let nameLower = remedyName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let services = AppGlobals.shared.treatmentServices

        // Exakter Match
        if let exact = services.first(where: {
            $0.de.lowercased() == nameLower || $0.en.lowercased() == nameLower
        }) {
            return exact
        }

        // BeginsWith
        if let fuzzy = services.first(where: {
            $0.de.lowercased().hasPrefix(nameLower) || $0.en.lowercased().hasPrefix(nameLower)
        }) {
            return fuzzy
        }

        // ID enthält Kürzel
        if let idMatch = services.first(where: {
            $0.id.lowercased().contains(nameLower)
        }) {
            return idMatch
        }

        return nil
    }
}

extension UIImage {
    func rotated90DegreesClockwise() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let newSize = CGSize(width: self.size.height, height: self.size.width)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // ✅ Verschiebe den Ursprung & rotiere
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: .pi / 2)

        // ✅ Damit es NICHT gespiegelt ist:
        context.scaleBy(x: 1.0, y: -1.0)

        let drawRect = CGRect(
            x: -self.size.width / 2,
            y: -self.size.height / 2,
            width: self.size.width,
            height: self.size.height
        )

        context.draw(cgImage, in: drawRect)

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
}
