//
//  InvoicePreviewView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 02.07.25.
//

import SwiftUI
import PDFKit

struct InvoicePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let media: MediaFile
    let invoice: Invoice
    let onCancel: () -> Void
    
    @State private var showCancelConfirmation = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            PDFKitView(url: fullURL)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Schließen
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Storno
                Button(action: {
                    showCancelConfirmation = true
                }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.error)
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .alert(isPresented: $showCancelConfirmation) {
                    Alert(
                        title: Text(NSLocalizedString("reversal", comment: "Reversal")),
                        message: Text(NSLocalizedString("reallyInvoiceReversal", comment: "Do you really want to reverse this invoice?")),
                        primaryButton: .destructive(Text(NSLocalizedString("ok", comment: "Ok"))) {
                            onCancel()
                            dismiss()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .padding(.top, 50)
            .padding(.leading, 20)
        }
    }

    private var fullURL: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent(media.relativePath)
    }
}
