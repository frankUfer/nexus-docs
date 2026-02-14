//
//  LabeledTextEditor.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 25.03.25.
//

import SwiftUI

struct LabeledTextEditor: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString(label, comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
