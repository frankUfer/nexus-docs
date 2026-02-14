//
//  PhoneNumberInfoRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.04.25.
//

import SwiftUI

struct PhoneNumberInfoRow: View {
    let label: String
    let number: String
    let icon: String?
    let color: Color?
    let region: String = "DE"  // optional anpassbar

    var body: some View {
        LabeledInfoRow(
            label: label,
            value: PhoneNumberHelper.shared.format(number, region: region),
            icon: icon,
            color: color
        )
    }
}
