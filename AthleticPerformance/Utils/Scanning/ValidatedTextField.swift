//
//  ValidatedTextField.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 02.04.25.
//

import SwiftUI

struct ValidatedTextField: View {
    var title: String
    @Binding var text: String
    var isValid: Bool
    var errorMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isValid ? Color.clear : Color.negativeCheck, lineWidth: 1)
                )
            if !isValid {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.negativeCheck)
            }
        }
        .padding(.vertical, 4)
    }
}
