//
//  TreatmentContractSection.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.05.25.
//

import SwiftUI
import PDFKit
import MessageUI

struct TreatmentContractSection: View {
    @Binding var patient: Patient
    @Binding var refreshTrigger: UUID
    @EnvironmentObject var patientStore: PatientStore

    @State private var showContractForm = false
    @State private var selectedPDFURL: URL? = nil
    @State private var showPDFPreview = false
    @State private var refreshID = UUID()
    
    @State private var selectedEmail: String?
    @State private var showMailComposer = false
    @State private var showEmailSelectionSheet = false
    @State private var encryptedPDFURL: URL?
    @State private var emailPassword: String?
    
    var body: some View {
        
        if let contractFolder = patientFolderURL(),
           FileManager.default.fileExists(atPath: contractFolder.path) {

            // 🔑 1️⃣ Alle Dateien holen
            let allFiles = (try? FileManager.default.contentsOfDirectory(at: contractFolder, includingPropertiesForKeys: nil)) ?? []

            // 🔑 2️⃣ Drafts filtern → nur echte Agreements
            let contractFiles = allFiles.filter { !$0.lastPathComponent.contains("draft") }

            // 🔑 3️⃣ Hauptvereinbarung
            let mainContract = contractFiles.first(where: { $0.lastPathComponent == "contract.pdf" })

            // 🔑 4️⃣ Archivierte
            let archiveContracts = contractFiles
                .filter { $0.lastPathComponent.hasPrefix("contract") && $0.lastPathComponent != "contract.pdf" }
                .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })

            DisplaySectionBox(
                title: "treatmentContract",
                lightAccentColor: .accentColor,
                darkAccentColor: .accentColor
            ) {
                VStack(alignment: .leading, spacing: 12) {

                    if let url = mainContract {
                        ContractThumbnailView(
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
                    
                    if !archiveContracts.isEmpty {
                        Text(NSLocalizedString("archivedContracts", comment: "Archived contracts"))
                            .font(.headline)

                        let gridItem = GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 10)

                        LazyVGrid(columns: [gridItem], spacing: 10) {
                            ForEach(archiveContracts, id: \.self) { url in
                                ContractThumbnailView(
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
                            Button(action: { showContractForm = true }) {
                                Label(NSLocalizedString("addTreatmentContract", comment: "Add contract"), systemImage: "plus")
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
                .fullScreenCover(isPresented: $showContractForm) {
                    if let template = loadContractTextTemplate().template {
                        let practiceInfo = AppGlobals.shared.practiceInfo

                        if let draftURL = ContractPDFGenerator.generatePDF(
                            plainText: template,
                            patient: patient,
                            practiceInfo: practiceInfo,
                            place: practiceInfo.address.city,
                            date: Date(),
                            signature: nil
                        ) {
                            ContractFormView(
                                pdfURL: draftURL,
                                patient: patient,
                                practiceInfo: practiceInfo
                            ) { signatureImage, place, date in
                        
                                if let contractFolder = patientFolderURL(),
                                   FileManager.default.fileExists(atPath: contractFolder.path),
                                   let existingContract = mainContract
                                {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "yyyy-MM-dd"
                                    let archiveName = "contract\(formatter.string(from: date)).pdf"
                                    let archiveURL = contractFolder.appendingPathComponent(archiveName)
                                    
                                    addSignatureToLastPage(
                                        of: existingContract,
                                        saveTo: archiveURL,
                                        place: place,
                                        date: date,
                                        signatureImageTherapist: UIImage(named: "PhysioSignature")!,
                                        signatureImagePatient: signatureImage,
                                        textLine: NSLocalizedString("contractReplacement", comment: "Contract Replacement"),
                                        font: .systemFont(ofSize: 11),
                                        textColor: .red
                                    )
                                }
                                
                                // ✅ Draft löschen NACH Final speichern
                                if let _ = ContractPDFGenerator.generatePDF(
                                    plainText: template,
                                    patient: patient,
                                    practiceInfo: practiceInfo,
                                    place: place,
                                    date: date,
                                    signature: signatureImage
                                ) {
                                    // Draft weg!
                                    try? FileManager.default.removeItem(at: draftURL)

                                    // patientStore.updatePatient(patient)
                                    refreshID = UUID()
                                    refreshTrigger = UUID()
                                }
                            }
                            .onDisappear {
                                // ✅ Fallback: Draft WEG wenn User abbricht!
                                try? FileManager.default.removeItem(at: draftURL)
                            }
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

