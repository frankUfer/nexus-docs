//
//  TherapistReadonlyView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

// 🔹 Anzeige-View für Therapeuten
struct TherapistsReadonlyView: View {
    let therapist: Therapists

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundColor(.icon)
                Text(therapist.firstname)
                Text(therapist.lastname)
            }

            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .foregroundColor(.icon)
                Text(therapist.email)

                Spacer()

                Image(systemName: therapist.isActive ? "checkmark.circle.fill" : "slash.circle")
                    .foregroundColor(therapist.isActive ? .positiveCheck : .gray)
            }
        }
        .padding(.vertical, 6)
    }
}
