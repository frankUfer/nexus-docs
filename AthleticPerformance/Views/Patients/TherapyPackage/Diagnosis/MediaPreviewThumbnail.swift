//
//  MediaPreviewThumbnail.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI
import PDFKit
import AVFoundation

struct MediaPreviewThumbnail: View {
    let media: MediaFile
    @Binding var mediaFiles: [MediaFile]
    @Binding var diagnosis: Diagnosis
    let selectedPatient: Patient
    let therapyId: UUID
    
    var onChange: (() -> Void)? = nil

    @State private var showPreviewCard = false
    
    var body: some View {
        ZStack {
            thumbnailContent
                .frame(width: 100, height: 100)
                .cornerRadius(8)
                .onTapGesture {
                    showPreviewCard = true
                }
        }
        .sheet(isPresented: $showPreviewCard) {
            MediaPreviewCardView(
                media: media,
                mediaFiles: $mediaFiles,
                diagnosis: $diagnosis,
                selectedPatientId: selectedPatient.id,
                therapyId: therapyId,
                onChange: onChange
            )
        }
    }

    private var thumbnailContent: some View {
        Group {
            switch media.fileType {
            case .image:
                if let image = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder.withIcon("photo")
                }

            case .video:
                if let image = generateThumbnail(for: fileURL) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder.withIcon("video.fill")
                }

            case .pdf:
                if let image = generatePDFThumbnail(for: fileURL) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder.withIcon("doc.richtext")
                }

            case .audio:
                placeholder.withIcon("waveform")
           
            case .csv:
                placeholder.withIcon("tablecells")
            
            default:
                placeholder.withIcon("doc")
            }
        }
    }
    
    private var fileURL: URL {
        // Hier wird das Dokumentenverzeichnis verwendet, anstatt das temporäre Verzeichnis
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent(media.relativePath)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
    }
    
    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            showErrorAlert(errorMessage: (NSLocalizedString("errorCreatingVideoThumbnail", comment: "Error creating video thumbnail.")))
            return nil
        }
    }

    private func generatePDFThumbnail(for url: URL) -> UIImage? {
        PDFHelper.generatePDFThumbnail(for: url)
    }
}

extension View {
    func withIcon(_ name: String) -> some View {
        self.overlay(
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.gray)
        )
    }
}

