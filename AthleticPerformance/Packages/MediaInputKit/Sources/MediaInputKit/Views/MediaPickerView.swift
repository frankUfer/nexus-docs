//
//  MediaPickerView.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//

import SwiftUI
import UIKit
import AVFoundation

public struct MediaPickerView: UIViewControllerRepresentable {
    public enum MediaKind {
        case photo
        case video
    }

    public typealias CompletionHandler = (_ image: UIImage?, _ url: URL?) -> Void

    private let kind: MediaKind
    private let onComplete: CompletionHandler

    public init(kind: MediaKind, onComplete: @escaping CompletionHandler) {
        self.kind = kind
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary

        switch kind {
        case .photo:
            picker.mediaTypes = ["public.image"]
        case .video:
            picker.mediaTypes = ["public.movie"]
        }

        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(kind: kind, onComplete: onComplete)
    }

    public class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let kind: MediaKind
        let onComplete: CompletionHandler

        init(kind: MediaKind, onComplete: @escaping CompletionHandler) {
            self.kind = kind
            self.onComplete = onComplete
        }

        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            var resultImage: UIImage? = nil
            var resultURL: URL? = nil

            switch kind {
            case .photo:
                resultImage = info[.originalImage] as? UIImage
                if let image = resultImage, let data = image.jpegData(compressionQuality: 0.8) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                    try? data.write(to: url)
                    resultURL = url
                }
            case .video:
                if let videoURL = info[.mediaURL] as? URL {
                    let asset = AVAsset(url: videoURL)
                    let imgGen = AVAssetImageGenerator(asset: asset)
                    imgGen.appliesPreferredTrackTransform = true
                    let time = CMTimeMake(value: 1, timescale: 2)
                    if let cgImage = try? imgGen.copyCGImage(at: time, actualTime: nil) {
                        resultImage = UIImage(cgImage: cgImage)
                    }
                    resultURL = videoURL
                }
            }

            picker.dismiss(animated: true) {
                self.onComplete(resultImage, resultURL)
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onComplete(nil, nil)
            }
        }
    }
}
