//
//  MediaInputView.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//
// Zentrale View mit einem Funktionsbalken, Galerie & Aktionsbuttons

import SwiftUI

public struct MediaInputView: View {
    public enum Mode {
        case diagnosis, finding
    }

    let mode: Mode
    let onFinished: ([MediaItem]) -> Void

    @State private var capturedItems: [MediaItem] = []

    public init(mode: Mode, onFinished: @escaping ([MediaItem]) -> Void) {
        self.mode = mode
        self.onFinished = onFinished
    }

    public var body: some View {
        VStack {
            Text("Media Input (\(modeLabel))")
                .font(.headline)

            MediaGalleryView(mediaItems: $capturedItems)

            HStack {
                Button("Foto aufnehmen") {
                    // TODO: Trigger Kameraansicht
                }
                Button("Dokument scannen") {
                    // TODO: Trigger Scan
                }
            }
            .padding()

            Button("Fertig") {
                onFinished(capturedItems)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var modeLabel: String {
        switch mode {
        case .diagnosis: return "Diagnose"
        case .finding: return "Befund"
        }
    }
}
