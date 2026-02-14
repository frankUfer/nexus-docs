//
//  TherapistListReadonlyView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct TherapistListReadonlyView: View {
    let therapists: [Therapists]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(therapists.enumerated()), id: \.element.id) { index, therapist in
                TherapistsReadonlyView(therapist: therapist)
                
                // Nur anzeigen, wenn NICHT der letzte
                if index < therapists.count - 1 {
                    Divider()
                        .background(Color.divider.opacity(0.5))
                }
            }
        }
    }
}
