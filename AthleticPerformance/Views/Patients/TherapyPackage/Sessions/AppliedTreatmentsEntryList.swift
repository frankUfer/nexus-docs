//
//  AppliedTreatmentsEntryList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 17.06.25.
//

import SwiftUI

struct AppliedTreatmentsEntryList: View {
    @Binding var appliedTreatments: [AppliedTreatment]
    let plan: TherapyPlan
    let allServices: [TreatmentService]

    let sessionId: UUID
    let sessionDocs: [TherapySessionDocumentation]

    var onEdited: () -> Void = {}

    var body: some View {
        DisplaySectionBox(
            title: NSLocalizedString("appliedTreatments", comment: "Applied Treatments"),
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(spacing: 12) {

                ForEach(plan.treatmentServiceIds, id: \.self) { serviceId in
                    if let service = allServices.first(where: { $0.internalId == serviceId }) {

                        HStack {
                            Text(service.id + " - " + service.de)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer()

                            let used = usedInOtherSessions(serviceId: serviceId)
                            let maxAllowed = max(plan.numberOfSessions - used, 0)

                            StepperWithValueLabel(
                                value: bindingForAmountSafe(
                                    serviceId: serviceId,
                                    maxAllowed: maxAllowed
                                ),
                                maxAllowed: maxAllowed
                            )
                        }

                    } else {
                        Text("❗ Unknown Service")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private func bindingForAmountSafe(
        serviceId: UUID,
        maxAllowed: Int
    ) -> Binding<Int> {

        if let idx = appliedTreatments.firstIndex(where: { $0.serviceId == serviceId }) {

            // Happy path: Eintrag existiert schon
            return Binding(
                get: {
                    appliedTreatments[idx].amount
                },
                set: { newValue in
                    let safeValue = min(newValue, maxAllowed)
                    appliedTreatments[idx].amount = safeValue
                    onEdited()
                }
            )

        } else {

            return Binding(
                get: {
                    0
                },
                set: { newValue in
                    let safeValue = min(newValue, maxAllowed)

                    appliedTreatments.append(
                        AppliedTreatment(
                            serviceId: serviceId,
                            amount: safeValue
                        )
                    )
                    onEdited()
                }
            )
        }
    }

    private func usedInOtherSessions(serviceId: UUID) -> Int {
        sessionDocs
            .filter { $0.sessionId != sessionId }
            .flatMap { $0.appliedTreatments }
            .filter { $0.serviceId == serviceId }
            .map { $0.amount }
            .reduce(0, +)
    }
}

private struct StepperWithValueLabel: View {
    @Binding var value: Int
    let maxAllowed: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .frame(width: 30, alignment: .trailing)

            Stepper(
                "",
                value: $value,
                in: 0...maxAllowed
            )
            .labelsHidden()
        }
    }
}
