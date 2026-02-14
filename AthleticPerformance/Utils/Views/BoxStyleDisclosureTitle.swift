//
//  BoxStyleDisclosureTitle.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 17.06.25.
//

import SwiftUI

struct BoxStyleDisclosureTitle: View {
    let text: String
    var body: some View {
        HStack {
            Text(text)
                .font(.headline)
                .foregroundColor(.accentColor)
            Spacer()
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
