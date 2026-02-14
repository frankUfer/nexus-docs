//
//  LabeledTextField.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import SwiftUI

struct LabeledTextField: View {
    let label: String
    let icon: String
    var iconColor: Color? = nil
    var keyboardType: UIKeyboardType = .default
    @Binding var text: String

    var body: some View {
        HStack {
            if !label.isEmpty || !icon.isEmpty {
                Label {
                    Text(NSLocalizedString(label, comment: ""))
                } icon: {
                    Image(systemName: icon)
                        .foregroundColor(iconColor ?? .primary)
                }
                .frame(width: 140, alignment: .leading)
            }

            TextField("", text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
        }
    }
}
