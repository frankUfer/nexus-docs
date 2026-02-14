//
//  InvoiceThumbnailGridView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 24.06.25.
//

import SwiftUI

struct InvoiceThumbnailGridView: View {
    @State private var invoiceFiles: [MediaFile] = []
    @State private var selectedInvoice: MediaFile? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(invoiceFiles) { file in
                    MediaPreviewThumbnail(
                        media: file,
                        mediaFiles: .constant(invoiceFiles),
                        diagnosis: .constant(Diagnosis.empty(with: UUID())),
                        selectedPatient: Patient(
                            title: .none,
                            firstname: "",
                            lastname: "",
                            birthdate: Date(),
                            sex: .unknown,
                            insuranceStatus: .other
                        ),
                        therapyId: UUID()
                    )
                    .onTapGesture {
                        selectedInvoice = file
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedInvoice) { file in
            MediaPreviewView(media: file)
        }
        .navigationTitle(NSLocalizedString("invoices", comment: "Invoices"))
        .onAppear {
            invoiceFiles = InvoiceFileManager.loadInvoicePDFMediaFiles()
        }
    }
}
