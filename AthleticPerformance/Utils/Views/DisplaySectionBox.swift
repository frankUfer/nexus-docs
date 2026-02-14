//
//  DisplaySectionBox.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 29.03.25.
//

import SwiftUI

struct DisplaySectionBox<Content: View>: View {
    let title: String
    let lightAccentColor: Color
    let darkAccentColor: Color
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        lightAccentColor: Color = Color.accentColor, //Color(.systemGray6),
        darkAccentColor: Color = Color.accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.lightAccentColor = lightAccentColor
        self.darkAccentColor = darkAccentColor
        self.content = content()
    }

    var currentAccentColor: Color {
        colorScheme == .dark ? darkAccentColor : lightAccentColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // 🔹 Titelzeile
            if !title.isEmpty {
                Text(NSLocalizedString(title, comment: ""))
                    .font(.headline)
                    //.foregroundColor(.white)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(currentAccentColor)
                    .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight]))
            }

            // 🔸 Inhalt
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .clipShape(
                RoundedCorner(
                    radius: 12,
                    corners: title.isEmpty ? .allCorners : [.bottomLeft, .bottomRight]
                )
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 5, x: 0, y: 2)
        )
        //.padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 12
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
