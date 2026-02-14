//
//  BoxStyleDisclosurePeriodTitle.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 17.06.25.
//

import SwiftUI

struct BoxStyleDisclosurePeriodTitle: View {
    let text: String
    let periodText: String?

    var body: some View {
        HStack {
            Text(text)
                .font(.headline)
                .foregroundColor(.accentColor)

            Spacer()

            if let periodText {
                Text(periodText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}
