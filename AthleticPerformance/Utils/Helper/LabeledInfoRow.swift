//
//  LabeledInfoRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 29.03.25.
//

import SwiftUI

struct LabeledInfoRow: View {
    let label: String
    let value: String
    let icon: String?
    let color: Color?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(color ?? .accentColor)
                    .frame(width: 40, alignment: .leading)
            }

            Text(NSLocalizedString(label, comment: ""))
                .foregroundColor(.secondary)
                .font(.subheadline)
                .frame(width: 160, alignment: .leading)

            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }
}
