//
//  IconNumberField.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import SwiftUI

struct IconNumberField: View {
    var icon: String
    var iconColor: Color = .gray
    @Binding var binding: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20, alignment: .leading)

            TextField("", value: $binding, formatter: NumberFormatter())
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
        }
    }
}
