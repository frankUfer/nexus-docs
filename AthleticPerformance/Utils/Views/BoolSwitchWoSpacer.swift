//
//  BoolSwitchwoSpacer.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 31.05.25.
//

import SwiftUI

struct BoolSwitchWoSpacer: View {
    @Binding var value: Bool
    var label: String

    var body: some View {
        HStack {
            Text(label)
            Button(action: { value.toggle() }) {
                Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(value ? .positiveCheck : .negativeCheck)
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
    }
}
