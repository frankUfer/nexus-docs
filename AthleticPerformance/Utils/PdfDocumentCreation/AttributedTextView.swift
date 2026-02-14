//
//  AttributedTextView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.03.25.
//

import SwiftUI
import UIKit

struct AttributedTextView: UIViewRepresentable {
    var attributedText: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.isUserInteractionEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.textContainerInset = .zero
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.backgroundColor = .clear
        uiView.isOpaque = false
        uiView.subviews.first?.backgroundColor = .clear
    }
}
