//
//  Traveltime.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 02.06.25.
//

import SwiftUI

struct TravelTimeConfirmationSheet: View {
    let estimatedMinutes: Int
    let origin: Address
    let destination: Address
    var onConfirm: (Int) -> Void
    var onCancel: () -> Void

    @State private var minutes: Int

    init(estimatedMinutes: Int, origin: Address, destination: Address, onConfirm: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.estimatedMinutes = estimatedMinutes
        self.origin = origin
        self.destination = destination
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _minutes = State(initialValue: estimatedMinutes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("plannedTour", comment: "Planned tour"))
                        .font(.headline)

                    Text("\(NSLocalizedString("from", comment: "From")): \(origin.fullDescription)")
                        .lineLimit(1)

                    Text("\(NSLocalizedString("to", comment: "To")): \(destination.fullDescription)")
                        .lineLimit(1)

                    Stepper(
                        "\(NSLocalizedString("travelTime", comment: "Travel time")): \(minutes) \(NSLocalizedString("minutes", comment: "Minutes"))",
                        value: $minutes,
                        in: 0...120
                    )
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("travelTimeAdjustment", comment: "Adjust travel time"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("confirm", comment: "Confirm")) {
                        onConfirm(minutes)
                    }
                    .foregroundColor(.addButton)
                }
            }
        }
    }
}
