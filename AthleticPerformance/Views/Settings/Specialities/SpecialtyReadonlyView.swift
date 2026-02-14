//
//  SpecialtyReadonlyView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.04.25.
//

import SwiftUI

struct SpecialtyReadonlyView: View {
    let specialties: [Specialty]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(specialties.sorted(by: { $0.localizedName() < $1.localizedName() })) { specialty in
                HStack(spacing: 12) {
                    Image(systemName: "staroflife")
                        .foregroundColor(.icon)
                    Text(specialty.localizedName())
                        .font(.body)
                    Spacer()
                    if specialty.source == "central" {
                        Image(systemName: "building.columns")
                            .foregroundColor(.gray)
                            .help(NSLocalizedString("sourceCentral", comment: "Central source"))
                    } else {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.positiveCheck)
                            .help(NSLocalizedString("sourceUser", comment: "User-defined source"))
                    }
                }
                Divider()
                .background(Color.divider.opacity(0.5))
            }
            if specialties.isEmpty {
                Text(NSLocalizedString("noSpecialtiesAvailable", comment: "No specialties available"))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}
