//
//  UIFont.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 27.06.25.
//

import UIKit

extension UIFont {
    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }

    private func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
