//
//  TherapyRowView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//

import SwiftUI

struct TherapyRowView: View {
    let therapy: Therapy

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(therapy.title)
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Text(therapy.startDate.formatted(date: .abbreviated, time: .omitted))
                if let end = therapy.endDate {
                    Text("– \(end.formatted(date: .abbreviated, time: .omitted))")
                }

                Spacer()

                if therapy.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.positiveCheck)
                        .accessibilityLabel(NSLocalizedString("therapyFinished", comment: "Therapy finished."))
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
