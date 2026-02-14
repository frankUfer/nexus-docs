//
//  BoolIndicatorWoSpacer.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 10.10.25.
//

import SwiftUI

struct BoolIndicatorWoSpacer: View {
    var value: Bool
    var label: String

    var body: some View {
        HStack {
            Text(label)
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(value ? .positiveCheck : .negativeCheck)
                .font(.title2)
        }
    }
}
