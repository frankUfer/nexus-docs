//
//  ZoomableImageView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()

        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = context.coordinator

        // ImageView Setup
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Double Tap Gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(scrollView)
        }

        private func centerImage(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }

            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            frameToCenter.origin.x = max((boundsSize.width - frameToCenter.size.width) * 0.5, 0)
            frameToCenter.origin.y = max((boundsSize.height - frameToCenter.size.height) * 0.5, 0)

            imageView.frame.origin = frameToCenter.origin
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            let zoomScale = scrollView.zoomScale
            let targetScale: CGFloat = zoomScale > 1.5 ? 1.0 : 3.0

            let pointInView = gesture.location(in: imageView)
            let scrollSize = scrollView.bounds.size

            let width = scrollSize.width / targetScale
            let height = scrollSize.height / targetScale
            let originX = pointInView.x - (width / 2)
            let originY = pointInView.y - (height / 2)

            let rectToZoom = CGRect(x: originX, y: originY, width: width, height: height)
            scrollView.zoom(to: rectToZoom, animated: true)
        }
    }
}
