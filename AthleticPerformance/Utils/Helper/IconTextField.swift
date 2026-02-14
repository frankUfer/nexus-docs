//
//  IconTextField.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import SwiftUI

struct IconTextField: View {
    let icon: String
    var iconColor: Color = .primary
    @Binding var binding: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            TextField("", text: $binding)
                .textFieldStyle(.roundedBorder)
        }
    }
}
