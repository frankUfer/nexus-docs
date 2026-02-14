//
//  StepperField.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import SwiftUI

struct StepperField: View {
    let label: String
    @Binding var value: Int
    var step: Int = 1

    var body: some View {
        HStack {
            Text(NSLocalizedString(label, comment: ""))
            Spacer()
            Stepper("", value: $value, in: 0...999, step: step)
            Text("\(value)")
                .frame(width: 30, alignment: .trailing)
        }
    }
}
