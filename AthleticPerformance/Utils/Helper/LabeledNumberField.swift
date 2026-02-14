//
//  LabeledNumberField.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import SwiftUI

struct LabeledNumberField: View {
    let label: String
    let icon: String
    @Binding var value: Int
    var width: CGFloat = 140

    var body: some View {
        HStack {
            Label(NSLocalizedString(label, comment: ""), systemImage: icon)
                .frame(width: width, alignment: .leading)

            TextField("", value: $value, formatter: NumberFormatter.integer)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
        }
    }
}
