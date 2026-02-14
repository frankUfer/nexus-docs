//
//  SignatureDrawingView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import SwiftUI
import PencilKit

struct SignatureDrawingView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
