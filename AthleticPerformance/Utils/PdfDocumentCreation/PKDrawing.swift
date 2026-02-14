//
//  PKDrawing.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import PencilKit
import UIKit

extension PKDrawing {
    func renderedBlackSignatureImage(scale: CGFloat = UIScreen.main.scale, padding: CGFloat = 12) -> UIImage {
        // 📏 Zeichenbereich mit zusätzlichem Rand
        let bounds = self.bounds.insetBy(dx: -padding, dy: -padding).integral
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false // Hintergrund bleibt transparent

        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)

        return renderer.image { context in
            let ctx = context.cgContext
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(2.0)

            // ➕ Zeichenursprung verschieben
            ctx.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)

            for stroke in self.strokes {
                let path = stroke.path
                var firstPoint = true
                for i in 0..<path.count {
                    let point = path[i].location
                    if firstPoint {
                        ctx.move(to: point)
                        firstPoint = false
                    } else {
                        ctx.addLine(to: point)
                    }
                }
                ctx.strokePath()
            }
        }
    }
}
