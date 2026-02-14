//
//  ReadonlyComponents.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.03.25.
//

import SwiftUI

struct ReadonlyRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(NSLocalizedString(label, comment: ""))
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SectionHeader: View {
    var titleKey: String

    var body: some View {
        Text(NSLocalizedString(titleKey, comment: ""))
            .font(.headline)
            .padding(.top, 16)
    }
}
