//
//  BoolSwitchDisclosure.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 21.06.25.
//

import SwiftUI

struct BoolSwitchDisclosure<Label: View>: View {
    @Binding var value: Bool
    var label: () -> Label

    var body: some View {
        HStack {
            label()
            Spacer()
            Button(action: { value.toggle() }) {
                Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(value ? .positiveCheck : .negativeCheck)
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
    }
}
