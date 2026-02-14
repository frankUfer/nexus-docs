//
//  AgreementFormView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import SwiftUI
import PDFKit
import PencilKit

struct AgreementFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var place: String = AppGlobals.shared.practiceInfo.address.city
    @State private var date: Date = Date()
    @State private var signature = PKCanvasView()
    @State private var showSuccessOverlay = false

    let pdfURL: URL
    let patient: Patient
    let practiceInfo: PracticeInfo
    let onComplete: (UIImage, String, Date) -> Void

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 20) {
                    PDFViewer(url: pdfURL)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker(
                            NSLocalizedString("date", comment: "Date"),
                            selection: $date,
                            displayedComponents: .date
                        )

                        Text(NSLocalizedString("signature", comment: "Signature"))
                            .font(.headline)

                        SignatureDrawingView(canvasView: $signature)
                            .frame(height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5))
                            )
                    }
                    .padding(.horizontal)

                    HStack {
                        Button(NSLocalizedString("cancel", comment: "Cancel")) {
                            try? FileManager.default.removeItem(at: pdfURL)
                            dismiss()
                        }
                        .foregroundColor(.cancel)

                        Spacer()

                        Button {
                            signature.drawing = PKDrawing()
                        } label: {
                            Label(NSLocalizedString("clearSignature", comment: "Clear signature"), systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.deleteButton)

                        Spacer()

                        Button(NSLocalizedString("save", comment: "Save")) {
                            saveAndComplete()
                        }
                        .foregroundColor(.done)
                        .bold()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .frame(width: 800)
                .cornerRadius(12)
                .shadow(radius: 8)
            }

            if showSuccessOverlay {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.positiveCheck)
                    Text(NSLocalizedString("agreementSavedMessage", comment: "Agreement saved"))
                        .font(.headline)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
                .transition(.scale)
            }
        }
    }

    private func saveAndComplete() {
        let drawing = signature.drawing
        guard !drawing.bounds.isEmpty else {
            showErrorAlert(errorMessage: NSLocalizedString("errorNoSignature", comment: "Error no signature"))
            dismiss()
            return
        }

        let rendered = drawing.renderedBlackSignatureImage()
        signature.drawing = PKDrawing()

        onComplete(rendered, place, date)
        try? FileManager.default.removeItem(at: pdfURL)

        withAnimation {
            showSuccessOverlay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccessOverlay = false
            dismiss()
        }
    }
}
