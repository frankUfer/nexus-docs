//
//  GeneratePDFThumbnail.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 04.07.25.
//

import Foundation
import UIKit
import PDFKit

struct PDFHelper {
    static func generatePDFThumbnail(for url: URL, targetSize: CGSize = CGSize(width: 100, height: 100)) -> UIImage? {
        guard let pdfDocument = PDFDocument(url: url),
              let page = pdfDocument.page(at: 0) else {
            return nil
        }

        let pageRect = page.bounds(for: .mediaBox)
        let scale = min(targetSize.width / pageRect.width, targetSize.height / pageRect.height)
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: origin.x, y: origin.y)
            ctx.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}
