//
//  AppliedTreatmentsList.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 25.10.25.
//

import SwiftUI

struct AppliedTreatmentsList: View {
    let treatmentServiceIds: [UUID]
    let appliedTreatmentsForSession: [AppliedTreatment]
    let allServices: [TreatmentService]    

    var body: some View {
        DisplaySectionBox(
            title: NSLocalizedString("appliedTreatments", comment: "Applied Treatments"),
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(spacing: 4) {

                ForEach(treatmentServiceIds, id: \.self) { serviceId in
                    if let service = allServices.first(where: { $0.internalId == serviceId }) {

                        let amountForThisSession = appliedTreatmentsForSession
                            .first(where: { $0.serviceId == serviceId })?
                            .amount ?? 0

                        HStack(alignment: .center, spacing: 12) {
                            Text("\(service.de) (\(service.quantity ?? 0) \(service.unit ?? ""))")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(amountForThisSession)")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 30, alignment: .trailing)
                        }

                        Divider()
                            .background(Color.divider.opacity(0.5))

                    } else {
                        Text("❗ Unknown Service: \(serviceId.uuidString)")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}
