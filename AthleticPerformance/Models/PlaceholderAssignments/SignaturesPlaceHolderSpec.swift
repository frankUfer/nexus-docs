//
//  ImagePlaceHolderSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 07.07.25.
//

import Foundation
import SwiftUI

struct SignaturePlaceholder {
    let signature: UIImage?
    let xPosition: CGFloat
    let label: String
}

func makeSignaturePlaceholders(patientSignature: UIImage?, layout: PageLayoutSpec) -> [SignaturePlaceholder] {
    return [
        SignaturePlaceholder(
            signature: UIImage(named: "PhysioSignature"),
            xPosition: layout.marginLeft,
            label: "(Physiotherapeut)"
        ),
        SignaturePlaceholder(
            signature: patientSignature,
            xPosition: layout.pageRect.width - layout.marginRight - 200,
            label: "(Patient)"
        )
    ]
}
