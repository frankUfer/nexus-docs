//
//  DecreaseFontSize.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import SwiftUI

func decreaseFontSize(in attributedString: NSMutableAttributedString, by points: CGFloat = 3) {
    attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length)) { value, range, _ in
        guard let font = value as? UIFont else { return }

        let newSize = max(font.pointSize - points, 1) // Mindestgröße 1 pt
        let newFont = UIFont(descriptor: font.fontDescriptor, size: newSize)
        attributedString.addAttribute(.font, value: newFont, range: range)
    }
}
