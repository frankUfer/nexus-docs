//
//  SectionBox.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.03.25.
//

import SwiftUI

struct SectionBox<Content: View>: View {
    let title: String
    let buttonLabel: String?
    let button: (() -> Void)?
    let content: Content

    init(
        title: String,
        buttonLabel: String? = nil,
        button: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.buttonLabel = buttonLabel
        self.button = button
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 🔹 Titelzeile mit optionalem Button
            HStack {
                Text(NSLocalizedString(title, comment: ""))
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if let button = button {
                    Button(action: button) {
                        Image(systemName: "pencil")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(NSLocalizedString(buttonLabel ?? "", comment: "")))
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal)
            .padding(.top, 0)

            // 🔸 Inhaltsbereich
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
