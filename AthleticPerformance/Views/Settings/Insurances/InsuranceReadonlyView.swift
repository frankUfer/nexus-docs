//
//  InsuranceReadonlyView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct InsuranceReadonlyView: View {
    let insurances: [InsuranceCompany]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(insurances.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })) { insurance in
                HStack(spacing: 12) {
                    Image(systemName: "shield")
                        .foregroundColor(.icon)

                    Text(insurance.name)
                        .font(.body)

                    Spacer()

                    if insurance.source == "central" {
                        Image(systemName: "building.columns") // Symbol für zentrale Quelle
                            .foregroundColor(.gray)
                            .help(NSLocalizedString("sourceCentral", comment: "Central source"))
                    } else {
                        Image(systemName: "person.crop.circle") // Symbol für Benutzerquelle
                            .foregroundColor(.positiveCheck)
                            .help(NSLocalizedString("sourceUser", comment: "User-defined source"))
                    }
                }
                Divider()
                .background(Color.divider.opacity(0.5))
            }

            if insurances.isEmpty {
                Text(NSLocalizedString("noInsurancesAvailable", comment: "No insurances available"))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}
