//
//  VideoCaptureView.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//

import SwiftUI
import UIKit
import AVFoundation

public struct VideoCaptureView: UIViewControllerRepresentable {
    public typealias CompletionHandler = (_ thumbnail: UIImage?, _ videoURL: URL?) -> Void

    private let onComplete: CompletionHandler

    public init(onComplete: @escaping CompletionHandler) {
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeMedium
        picker.cameraCaptureMode = .video
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    public class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onComplete: CompletionHandler

        init(onComplete: @escaping CompletionHandler) {
            self.onComplete = onComplete
        }

        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let videoURL = info[.mediaURL] as? URL else {
                picker.dismiss(animated: true) {
                    self.onComplete(nil, nil)
                }
                return
            }

            // Erstelle Vorschaubild aus Video
            let asset = AVAsset(url: videoURL)
            let assetImgGenerate = AVAssetImageGenerator(asset: asset)
            assetImgGenerate.appliesPreferredTrackTransform = true

            let time = CMTimeMake(value: 1, timescale: 2)
            var image: UIImage? = nil
            if let cgImage = try? assetImgGenerate.copyCGImage(at: time, actualTime: nil) {
                image = UIImage(cgImage: cgImage)
            }

            picker.dismiss(animated: true) {
                self.onComplete(image, videoURL)
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onComplete(nil, nil)
            }
        }
    }
}
