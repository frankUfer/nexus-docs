//
//  InvoiceOverviewView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 24.06.25.
//

import SwiftUI
import PDFKit
import MessageUI

struct InvoiceOverviewView: View {
    let invoices: [Invoice]
    let onInvoicesSent: () -> Void
    
    @State private var invoiceFiles: [MediaFile] = []
    @State private var selectedInvoices: Set<MediaFile> = []
    @State private var selectedInvoiceForPreview: MediaFile? = nil
    @State private var expandedPatients: Set<UUID> = []
    @State private var invoiceMap: [String: Invoice] = [:]
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var retainedMailDelegate: MailDelegate? = nil
    
    @EnvironmentObject var patientStore: PatientStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 🔹 Senden nur aktiv, wenn etwas selektiert ist
                if !selectedInvoices.isEmpty {
                    Button(action: {
                        sendSelectedInvoices()
                    }) {
                        Label(NSLocalizedString("sendInvoices", comment: "Send invoices"), systemImage: "paperplane.fill")
                            .foregroundColor(.positiveCheck)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                if !invoiceFiles.isEmpty {
                    BoolSwitchWoSpacer(
                        value: Binding(
                            get: { selectedInvoices.count == invoiceFiles.count && !invoiceFiles.isEmpty },
                            set: { isSelected in
                                if isSelected {
                                    selectedInvoices = Set(invoiceFiles)
                                } else {
                                    selectedInvoices.removeAll()
                                }
                            }
                        ),
                        label: NSLocalizedString("selectAll", comment: "Alle auswählen")
                    )
                    .padding(.horizontal)
                }
            }
            
            ForEach(groupedInvoices(), id: \.patientId) { group in
                patientGroupView(group)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            let allFiles = InvoiceFileManager.loadInvoicePDFMediaFiles()

            // ✅ Nur Originale & Gutschriften
            let validInvoices = invoices.filter {
                $0.invoiceType == .invoice || $0.invoiceType == .creditNote
            }

            // ✅ Passende PDFs rausfiltern
            invoiceFiles = allFiles.filter { file in
                validInvoices.contains { inv in
                    let number = inv.invoiceNumber
                    return "\(number).pdf" == file.filename
                }
            }
            .sorted { a, b in
                let n1 = InvoiceFileManager.extractInvoiceNumber(from: a.filename)
                let n2 = InvoiceFileManager.extractInvoiceNumber(from: b.filename)
                return n1 < n2
            }

            // ✅ PDF → Invoice Map
            invoiceMap = Dictionary(
                uniqueKeysWithValues: validInvoices.map {
                    ("\($0.invoiceNumber).pdf", $0)
                }
            )
        }
        
        .sheet(item: $selectedInvoiceForPreview) { file in
            if let invoice = invoiceMap[file.filename] {
                InvoicePreviewView(
                    media: file,
                    invoice: invoice,
                    onCancel: {
                        do {
                            try InvoiceReversal(invoice, patientStore: patientStore)
                            toastMessage = "Storno erstellt."
                            showToast = true
                            onInvoicesSent()
                        } catch {
                            showErrorAlert(errorMessage: error.localizedDescription)
                        }
                    }
                )
            } else {
                Text("Kein passendes Invoice-Objekt gefunden.")
            }
        }
        
        if showToast {
               ToastView(message: toastMessage)
                   .zIndex(1)
                   .onAppear {
                       DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                           withAnimation {
                               showToast = false
                           }
                       }
                   }
           }
    }
    
    private func groupedInvoices() -> [(patientId: UUID, patientName: String, files: [MediaFile])] {
        let dict = InvoiceFileManager.groupMediaFilesByPatient(invoiceFiles)

        return dict.map { (patientId, files) in
            let name = patientStore.patients.first(where: { $0.id == patientId })
                .map { "\($0.firstname) \($0.lastname)" }
                ?? NSLocalizedString("unknownPatient", comment: "Unknown patient")
            return (patientId: patientId, patientName: name, files: files)
        }
        .sorted { $0.patientName < $1.patientName }
    }
    
    private func patientGroupView(_ group: (patientId: UUID, patientName: String, files: [MediaFile])) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedPatients.contains(group.patientId) },
                set: { isExpanded in
                    if isExpanded {
                        expandedPatients.insert(group.patientId)
                    } else {
                        expandedPatients.remove(group.patientId)
                    }
                }
            )
        ) {
            invoiceGrid(for: group.files)
                .opacity(expandedPatients.contains(group.patientId) ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: expandedPatients.contains(group.patientId))
        } label: {
            HStack {
                BoolSwitchWoSpacer(
                    value: Binding(
                        get: {
                            Set(group.files).isSubset(of: selectedInvoices)
                            && !group.files.isEmpty
                        },
                        set: { isSelected in
                            if isSelected {
                                selectedInvoices.formUnion(group.files)
                            } else {
                                selectedInvoices.subtract(group.files)
                            }
                        }
                    ),
                    label: group.patientName
                )
                .font(.headline)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(group.files.count) \(NSLocalizedString("invoices", comment: "Invoices"))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator)))
        .padding(.horizontal)
    }
    
    private func invoiceGrid(for files: [MediaFile]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
            ForEach(files) { file in
                let invoice = invoiceMap[file.filename]
                invoiceTile(for: file, invoice: invoice)
            }
        }
        .padding(.top, 8)
    }
    
    private func invoiceTile(for file: MediaFile, invoice: Invoice?) -> some View {
        VStack {
            if let thumb = generatePDFThumbnail(for: file) {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(Image(systemName: "doc").foregroundColor(.gray))
            }
            
            Text(file.filename)
                .font(.caption2)
                .lineLimit(1)
        }
        .onTapGesture {
            toggleSelection(for: file)
        }
        .overlay(
            CheckmarkOverlay(isSelected: selectedInvoices.contains(file)),
            alignment: .topTrailing
        )
        .onLongPressGesture {
            selectedInvoiceForPreview = file
        }
    }
    
    private func toggleSelection(for file: MediaFile) {
        if selectedInvoices.contains(file) {
            selectedInvoices.remove(file)
        } else {
            selectedInvoices.insert(file)
        }
    }
    
    private func generatePDFThumbnail(for file: MediaFile) -> UIImage? {
        PDFHelper.generatePDFThumbnail(for: file.fullURL)
    }

    private func sendSelectedInvoices() {
        let grouped = Dictionary(grouping: selectedInvoices) { file in
            let parts = file.relativePath.split(separator: "/")
            if parts.count >= 2, let uuid = UUID(uuidString: String(parts[1])) {
                return uuid
            }
            return UUID()
        }

        for (patientId, files) in grouped {
            guard let patient = patientStore.patients.first(where: { $0.id == patientId }) else {
                let message = "\(String(format: NSLocalizedString("errorPatientNotFound", comment: "Error patient not found"))): \(patientId)"
                showErrorAlert(errorMessage: message)
                continue
            }

            let urls = files.map(\.fullURL)
            sendSelectedInvoices(for: patient, files: urls, invoiceMap: invoiceMap)
        }
    }
        
    private func sendSelectedInvoices(for patient: Patient, files: [URL], invoiceMap: [String: Invoice]) {
        guard !patient.emailAddresses.isEmpty else {
            showErrorAlert(errorMessage: NSLocalizedString("noEmailFound", comment: "No email found"))
            return
        }

        func presentMailComposer(to recipient: String) {
            guard MFMailComposeViewController.canSendMail() else {
                showErrorAlert(errorMessage: NSLocalizedString("mailUnavailable", comment: "Mail unavailable"))
                return
            }

            let mailVC = MFMailComposeViewController()
            mailVC.setToRecipients([recipient])

            // 👉 Betreff je nach Anzahl
            let invoiceNumbers = files.compactMap { invoiceMap[$0.lastPathComponent]?.invoiceNumber }
            
            let subject = invoiceNumbers.count == 1
            ? (patient.firstnameTerms
                    ? NSLocalizedString("invoiceSubjectFirstnameTerms", comment: "")
                    : NSLocalizedString("invoiceSubject", comment: ""))
            : (patient.firstnameTerms
                    ? NSLocalizedString("invoicesSubjectFirstnameTerms", comment: "")
                    : NSLocalizedString("invoicesSubject", comment: ""))

            let introductoryText = patient.firstnameTerms
                    ? NSLocalizedString("introText1FirstnameTerms", comment: "") + patient.firstname
                    : NSLocalizedString("introText1", comment: "") + patient.fullName
                    
            let invoiceBody = invoiceNumbers.count == 1
            ? (patient.firstnameTerms
                    ? NSLocalizedString("invoiceBodyFirstnameTerms", comment: "")
                    : NSLocalizedString("invoiceBody", comment: ""))
            : (patient.firstnameTerms
                    ? NSLocalizedString("invoicesBodyFirstnameTerms", comment: "")
                    : NSLocalizedString("invoicesBody", comment: ""))

            mailVC.setSubject(subject)

            let message = """
            \(introductoryText)

            \(invoiceBody)
            
            """
            
            mailVC.setMessageBody(message, isHTML: false)

            // 👉 Anhänge
            for file in files {
                if let invoice = invoiceMap[file.lastPathComponent],
                   let pdfData = try? Data(contentsOf: file) {
                    mailVC.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: "\(invoice.invoiceNumber).pdf")
                }
            }

            // 👉 Delegate
            let mailDelegate = MailDelegate { result in
                switch result {
                case .sent:
                    for file in files {
                        if let invoice = invoiceMap[file.lastPathComponent] {
                            InvoiceFileManager.markInvoiceAsSent(
                                invoiceNumber: invoice.invoiceNumber,
                                patientId: invoice.patientId
                            )
                        }
                    }
                    onInvoicesSent()
                    toastMessage = NSLocalizedString("mailSent", comment: "Mail sent")
                case .cancelled:
                    toastMessage = NSLocalizedString("mailCancelled", comment: "Mail cancelled")
                case .saved:
                    toastMessage = NSLocalizedString("mailSaved", comment: "Mail saved")
                case .failed:
                    toastMessage = NSLocalizedString("mailFailed", comment: "Mail failed")
                @unknown default:
                    toastMessage = NSLocalizedString("mailUnknown", comment: "Mail unknown")
                }

                withAnimation { showToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showToast = false
                        toastMessage = ""
                    }
                }

                retainedMailDelegate = nil
            }
            retainedMailDelegate = mailDelegate
            mailVC.mailComposeDelegate = mailDelegate

            // 👉 Anzeigen
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                rootVC.present(mailVC, animated: true)
            }
        }

        // 👉 Direkt oder Auswahl bei mehreren Mails
        if patient.emailAddresses.count == 1 {
            presentMailComposer(to: patient.emailAddresses[0].value)
        } else {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: NSLocalizedString("chooseEmail", comment: "Choose Email"),
                    message: nil,
                    preferredStyle: .actionSheet
                )

                for entry in patient.emailAddresses {
                    alert.addAction(UIAlertAction(
                        title: "\(NSLocalizedString(entry.label, comment: "")): \(entry.value)",
                        style: .default
                    ) { _ in
                        presentMailComposer(to: entry.value)
                    })
                }

                alert.addAction(UIAlertAction(
                    title: NSLocalizedString("cancel", comment: "Cancel"),
                    style: .cancel
                ))

                rootVC.present(alert, animated: true)
            }
        }
    }
}

struct CheckmarkOverlay: View {
    let isSelected: Bool
    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? .positiveCheck : .gray)
            .padding(4)
    }
}
