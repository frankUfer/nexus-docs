//
//  MediaPreviewView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI
import PDFKit
import AVKit
import AVFoundation

struct MediaPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    let media: MediaFile
    
    var body: some View {
        Group {
            switch media.fileType {
            
            case .image:
                imagePreview
            
            case .pdf:
                AnyView(
                    ZStack(alignment: .topLeading) {
                        PDFKitView(url: fullURL)
                            .ignoresSafeArea()

                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .padding(10)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .padding(.top, 50)
                                .padding(.leading, 20)
                        }
                        .buttonStyle(.plain)
                    }
                )
                        
            case .csv:
                if let table = CSVTable(from: fullURL) {
                    let widths = calculateColumnWidths(for: table, fontSize: 16)
                    AnyView(CSVTableView(table: table, columnWidths: widths))
                } else {
                    AnyView(Text(NSLocalizedString("errorCSVLoading", comment: "CSV file could not be loaded.")))
                }

                
            case .video:
                ZoomableVideoWrapper(url: fullURL)
            
            default:
                unsupportedFileView
            }
        }
    }
    
    private var fullURL: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = documentDirectory.appendingPathComponent(media.relativePath)
        return url
    }
    
    private var imagePreview: some View {
        if let image = UIImage(contentsOfFile: fullURL.path) {
            return AnyView(
                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()

                    ZoomableImageView(image: image)
                        .ignoresSafeArea()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(.top, 50)
                            .padding(.leading, 20)
                    }
                    .buttonStyle(.plain)
                }
            )
        } else {
            return AnyView(
                ZStack {
                    Color.black.ignoresSafeArea()
                    Text(NSLocalizedString("errorImageLoading", comment: "Image could not be loaded."))
                        .foregroundColor(.white)
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(.top, 50)
                            .padding(.leading, 20)
                    }
                    .buttonStyle(.plain)
                }
            )
        }
    }
        
    private var unsupportedFileView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text(media.filename)
                .font(.headline)

            Text(NSLocalizedString("unsupportedFileFormat", comment: "Unsupported file format."))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
