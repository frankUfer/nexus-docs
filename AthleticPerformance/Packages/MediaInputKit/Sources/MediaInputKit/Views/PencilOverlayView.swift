//
//  PencilOverlay.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//

import SwiftUI
import PencilKit

public struct PencilOverlayView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    public init(drawing: Binding<PKDrawing>) {
        self._drawing = drawing
    }

    public func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.tool = PKInkingTool(.pen, color: .blue, width: 5)
        canvasView.drawing = drawing
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }
}
