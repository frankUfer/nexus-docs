//
//  InsuranceInfoSection.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.03.25.
//

import SwiftUI

struct InsuranceInfoSection: View {
    @Binding var insuranceStatus: InsuranceStatus
    @Binding var insurance: String
    @Binding var insuranceNumber: String
    @Binding var familyDoctor: String

    var body: some View {
        Section(header: Text(NSLocalizedString("insuranceInformation", comment: "Insurance information"))) {
            Picker(NSLocalizedString("insuranceStatus", comment: "Insurance status"), selection: $insuranceStatus) {
                ForEach(InsuranceStatus.allCases, id: \.self) { status in
                    Text(NSLocalizedString(status.rawValue, comment: "")).tag(status)
                }
            }

            Picker(NSLocalizedString("insurance", comment: "Insurance"), selection: $insurance) {
                ForEach(AppGlobals.shared.insuranceList, id: \.id) { entry in
                    Text(entry.name).tag(entry.name)
                }
            }

            TextField(NSLocalizedString("insuranceNumber", comment: "Insurance number"), text: $insuranceNumber)
                .textContentType(.name)
                .textInputAutocapitalization(.never)

            TextField(NSLocalizedString("familyDoctor", comment: "Family doctor"), text: $familyDoctor)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
        }
    }
}
