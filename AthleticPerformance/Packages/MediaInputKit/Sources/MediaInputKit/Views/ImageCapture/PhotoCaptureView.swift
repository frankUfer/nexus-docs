//
//  PhotoCapture.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//

import SwiftUI

public struct PhotoCaptureView: UIViewControllerRepresentable {
    public typealias CompletionHandler = (_ image: UIImage?, _ url: URL?) -> Void

    private let onComplete: CompletionHandler

    public init(onComplete: @escaping CompletionHandler) {
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
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

        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            var tempURL: URL?

            if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
                let filename = UUID().uuidString + ".jpg"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try? data.write(to: url)
                tempURL = url
            }

            picker.dismiss(animated: true) {
                self.onComplete(image, tempURL)
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onComplete(nil, nil)
            }
        }
    }
}
