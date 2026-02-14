//
//  DrawingCanvasView.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//

import SwiftUI

struct DrawingCanvasView: View {
    @Binding var shapes: [AngleShape]
    @State private var selectedShapeID: UUID?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach($shapes) { $shape in
                    AngleShapeView(
                        shape: $shape,
                        canvasSize: geometry.size
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if shape.isSelected {
                                    let dx = value.translation.width
                                    let dy = value.translation.height
                                    shape.origin.x += dx
                                    shape.origin.y += dy
                                    shape.point1.x += dx
                                    shape.point1.y += dy
                                    shape.point2.x += dx
                                    shape.point2.y += dy
                                }
                            }
                    )
                }
            }
        }
    }
}
