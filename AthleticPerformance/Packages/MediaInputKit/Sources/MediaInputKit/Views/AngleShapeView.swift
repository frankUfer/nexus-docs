//
//  AngleShapeView.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//

import SwiftUI

public struct AngleShapeView: View {
    @Binding var shape: AngleShape
    let canvasSize: CGSize

    public init(shape: Binding<AngleShape>, canvasSize: CGSize) {
        self._shape = shape
        self.canvasSize = canvasSize
    }

    @State private var lastDragLocation: CGPoint?

    public var body: some View {
        ZStack {
            // Linien
            Path { path in
                path.move(to: shape.origin)
                path.addLine(to: shape.point1)
                path.move(to: shape.origin)
                path.addLine(to: shape.point2)
            }
            .stroke(shape.color, lineWidth: shape.isSelected ? 4 : 2)

            // Punkte
            Circle().fill(Color.white).frame(width: 16, height: 16).position(shape.point1)
            Circle().fill(Color.white).frame(width: 16, height: 16).position(shape.point2)

            // Ursprungs-Punkt (drag-gesteuert)
            Circle()
                .stroke(Color.red, lineWidth: 2)
                .frame(width: 30, height: 30)
                .position(shape.origin)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let delta = value.translation

                            // neuen Punkt berechnen
                            let newOrigin = CGPoint(
                                x: shape.origin.x + delta.width,
                                y: shape.origin.y + delta.height
                            )

                            // alle Punkte relativ verschieben
                            let newPoint1 = CGPoint(
                                x: shape.point1.x + delta.width,
                                y: shape.point1.y + delta.height
                            )
                            let newPoint2 = CGPoint(
                                x: shape.point2.x + delta.width,
                                y: shape.point2.y + delta.height
                            )

                            // Boundaries prüfen
                            if canvasContains(points: [newOrigin, newPoint1, newPoint2]) {
                                shape.origin = newOrigin
                                shape.point1 = newPoint1
                                shape.point2 = newPoint2
                            }
                        }
                )

            // Winkeltext
            if let angle = angleInDegrees(), angle < 180 {
                Text("\(Int(angle))°")
                    .font(.caption)
                    .foregroundColor(.black)
                    .background(Color.white.opacity(0.7))
                    .position(angleTextPosition())
            }
        }
    }

    private func angleInDegrees() -> CGFloat? {
        let v1 = CGVector(dx: shape.point1.x - shape.origin.x, dy: shape.point1.y - shape.origin.y)
        let v2 = CGVector(dx: shape.point2.x - shape.origin.x, dy: shape.point2.y - shape.origin.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let len1 = v1.length
        let len2 = v2.length

        guard len1 > 0 && len2 > 0 else { return nil }

        let angle = acos(dot / (len1 * len2))
        return angle.isNaN ? nil : angle * 180 / .pi
    }

    private func angleTextPosition() -> CGPoint {
        CGPoint(x: shape.origin.x + 30, y: shape.origin.y - 30)
    }

    private func canvasContains(points: [CGPoint]) -> Bool {
        for point in points {
            if point.x < 0 || point.y < 0 || point.x > canvasSize.width || point.y > canvasSize.height {
                return false
            }
        }
        return true
    }
}

private extension CGVector {
    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }
}
