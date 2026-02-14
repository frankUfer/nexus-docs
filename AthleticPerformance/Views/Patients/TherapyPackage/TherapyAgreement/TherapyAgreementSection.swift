//
//  TherapyAgreementSection.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import SwiftUI
import PDFKit
import MessageUI

struct TherapyAgreementSection: View {
    @Binding var patient: Patient
    @Binding var therapy: Therapy
    @Binding var refreshTrigger: UUID
    @EnvironmentObject var patientStore: PatientStore

    @State private var showAgreementForm = false
    @State private var selectedPDFURL: URL? = nil
    @State private var showPDFPreview = false
    @State private var refreshID = UUID()
    
    @State private var selectedEmail: String?
    @State private var showMailComposer = false
    @State private var showEmailSelectionSheet = false
    @State private var encryptedPDFURL: URL?
    @State private var emailPassword: String?
        
    var body: some View {
        let agreementFolder = patientFolderURL()?.appendingPathComponent("therapy_\(therapy.id)")
        let folderExists = agreementFolder.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        
        let allFiles: [URL] = {
            guard folderExists, let folder = agreementFolder else { return [] }
            return (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        }()
        
        let agreementFiles = allFiles.filter { !$0.lastPathComponent.contains("draft") }
        let mainAgreement = agreementFiles.first(where: { $0.lastPathComponent == "agreement.pdf" })
        let archiveAgreements = agreementFiles
            .filter { $0.lastPathComponent.hasPrefix("agreement") && $0.lastPathComponent != "agreement.pdf" }
            .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        
        DisplaySectionBox(
            title: "therapyAgreement",
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(alignment: .leading, spacing: 12) {
                
                if let url = mainAgreement {
                    AgreementThumbnailView(
                        fileURL: url,
                        patient: patient,
                        onTap: {
                            selectedPDFURL = url
                            showPDFPreview = true
                        },
                        onDelete: {
                            try? FileManager.default.removeItem(at: url)
                            refreshID = UUID()
                            refreshTrigger = UUID()
                        },
                        selectedEmail: $selectedEmail,
                        showMailComposer: $showMailComposer,
                        showEmailSelectionSheet: $showEmailSelectionSheet,
                        encryptedPDFURL: $encryptedPDFURL,
                        emailPassword: $emailPassword
                    )
                }
                
                if !archiveAgreements.isEmpty {
                    Text(NSLocalizedString("archivedAgreements", comment: "Archived agreements"))
                        .font(.headline)

                    let gridItem = GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 10)

                    LazyVGrid(columns: [gridItem], spacing: 10) {
                        ForEach(archiveAgreements, id: \.self) { url in
                            AgreementThumbnailView(
                                fileURL: url,
                                patient: patient,
                                onTap: {
                                    selectedPDFURL = url
                                    showPDFPreview = true
                                },
                                onDelete: {
                                    try? FileManager.default.removeItem(at: url)
                                    refreshID = UUID()
                                    refreshTrigger = UUID()
                                },
                                selectedEmail: $selectedEmail,
                                showMailComposer: $showMailComposer,
                                showEmailSelectionSheet: $showEmailSelectionSheet,
                                encryptedPDFURL: $encryptedPDFURL,
                                emailPassword: $emailPassword
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                
                if patient.isActive {
                    HStack {
                        Spacer()
                        Button(action: { showAgreementForm = true }) {
                            Label(NSLocalizedString("addTherapyAgreement", comment: "Add therapy agreement"), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 8)
                }
            }
            .id(refreshID)
            .sheet(isPresented: $showPDFPreview) {
                if let url = selectedPDFURL {
                    PDFPreviewView(url: url)
                }
            }
            .fullScreenCover(isPresented: $showAgreementForm) {
                if let template = loadAgreementTextTemplate().template {
                    let practiceInfo = AppGlobals.shared.practiceInfo

                    if let draftURL = AgreementPDFGenerator.generatePDF(
                        plainText: template,
                        patient: patient,
                        practiceInfo: practiceInfo,
                        therapy: therapy,
                        therapyId: therapy.id,
                        place: practiceInfo.address.city,
                        date: Date(),
                        signature: nil
                    ) {
                        AgreementFormView(
                            pdfURL: draftURL,
                            patient: patient,
                            practiceInfo: practiceInfo
                        ) { signatureImage, place, date in
                            
                            // 📁 Ordner ggf. erzeugen
                            if let folder = agreementFolder,
                               !FileManager.default.fileExists(atPath: folder.path) {
                                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            }
                            
                            if let existingAgreement = mainAgreement,
                               let folder = agreementFolder {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd"
                                let archiveName = "agreement\(formatter.string(from: date)).pdf"
                                let archiveURL = folder.appendingPathComponent(archiveName)
                                
                                addSignatureToLastPage(
                                    of: existingAgreement,
                                    saveTo: archiveURL,
                                    place: place,
                                    date: date,
                                    signatureImageTherapist: UIImage(named: "PhysioSignature")!,
                                    signatureImagePatient: signatureImage,
                                    textLine: NSLocalizedString("agreementReplacement", comment: "Agreement Replacement"),
                                    font: .systemFont(ofSize: 11),
                                    textColor: .red
                                )
                            }
                            
                            if let _ = AgreementPDFGenerator.generatePDF(
                                plainText: template,
                                patient: patient,
                                practiceInfo: practiceInfo,
                                therapy: therapy,
                                therapyId: therapy.id,
                                place: place,
                                date: date,
                                signature: signatureImage
                            ) {
                                try? FileManager.default.removeItem(at: draftURL)
                                
                                therapy.isAgreed = true
                                if let index = patient.therapies.firstIndex(where: { $0?.id == therapy.id }) {
                                    patient.therapies[index] = therapy
                                }
                                
                                // patientStore.updatePatient(patient)
                                refreshID = UUID()
                                refreshTrigger = UUID()
                            }
                        }
                        .onDisappear {
                            try? FileManager.default.removeItem(at: draftURL)
                        }
                    }
                }
            }
        }
    }

    private func patientFolderURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("patients")
            .appendingPathComponent(patient.id.uuidString)
    }
}
