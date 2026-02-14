//
//  VisionScannerView.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 25.04.25.
//

import SwiftUI
import VisionKit
import Vision
import PDFKit

public enum ScanMode {
    case image, pdf
}

public enum ScanOutput {
    case image(UIImage)
    case pdf(Data)
}

public struct VisionScannerView: UIViewControllerRepresentable {
    public var mode: ScanMode
    public var onScanCompleted: (Result<ScanOutput, Error>) -> Void
    
    public init(mode: ScanMode, onScanCompleted: @escaping (Result<ScanOutput, Error>) -> Void) {
        self.mode = mode
        self.onScanCompleted = onScanCompleted
    }
    
    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, onScanCompleted: onScanCompleted)
    }
    
    public class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let mode: ScanMode
        let onScanCompleted: (Result<ScanOutput, Error>) -> Void
        
        init(mode: ScanMode, onScanCompleted: @escaping (Result<ScanOutput, Error>) -> Void) {
            self.mode = mode
            self.onScanCompleted = onScanCompleted
        }
        
        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                Task { @MainActor in
                    controller.dismiss(animated: true)
                }
                return
            }

            // Wenn mehrere Seiten gescannt wurden, erstelle ein PDF
            if scan.pageCount > 1 {
                if let pdfData = createPDF(from: scan) {
                    onScanCompleted(.success(.pdf(pdfData)))
                } else {
                    onScanCompleted(.failure(NSError(domain: "PDFError", code: 1)))
                }
            } else {
                // Wenn nur eine Seite gescannt wurde, gebe nur das Bild zurück
                let image = scan.imageOfPage(at: 0)
                onScanCompleted(.success(.image(image)))
            }

            Task { @MainActor in
                controller.dismiss(animated: true)
            }
        }
        
        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            Task { @MainActor in
                controller.dismiss(animated: true)
            }
        }
        
        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onScanCompleted(.failure(error))
            Task { @MainActor in
                controller.dismiss(animated: true)
            }
        }
        
        // Funktion zum Erstellen eines PDFs aus den gescannten Seiten
        private func createPDF(from scan: VNDocumentCameraScan) -> Data? {
            let pdf = PDFDocument()
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                if let pdfPage = PDFPage(image: image) {
                    pdf.insert(pdfPage, at: i)
                }
            }
            return pdf.dataRepresentation()
        }
    }
}
