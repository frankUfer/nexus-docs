//
//  ZoomableVideoPlayerView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI
import AVKit
import AVFoundation

struct ZoomableVideoPlayerView: UIViewRepresentable {
    let url: URL
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black

        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = container.bounds

        context.coordinator.playerLayer = playerLayer
        container.layer.addSublayer(playerLayer)

        player.play()
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerLayer = context.coordinator.playerLayer else { return }
        playerLayer.frame = uiView.bounds

        let transform = CGAffineTransform.identity
            .translatedBy(x: offset.width, y: offset.height)
            .scaledBy(x: scale, y: scale)

        playerLayer.setAffineTransform(transform)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}
