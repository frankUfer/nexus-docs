//
//  CheckCalenderEntries.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 06.10.25.
//

import Foundation

struct CalendarIndexBackfiller {
    /// Läuft beim App-Start:
    /// - Prüft für alle Patienten/Therapiepläne, ob `serialNumber` gesetzt ist.
    /// - Falls nicht, nummeriert den Plan neu und speichert den Patient.
    static func runAtAppStart(patients: [Patient], patientStore: PatientStore) {
        guard !patients.isEmpty else { return }

        Task.detached(priority: .utility) {
            var changedCount = 0
            var retitledSessions = 0

            for var patient in patients {
                var patientChanged = false

                // Therapien können optional sein
                for tIdx in patient.therapies.indices {
                    guard var therapy = patient.therapies[tIdx] else { continue }

                    for plIdx in therapy.therapyPlans.indices {
                        var plan = therapy.therapyPlans[plIdx]
                        guard !plan.treatmentSessions.isEmpty else { continue }

                        // Braucht dieser Plan ein Backfill?
                        let needsBackfill = plan.treatmentSessions.contains { $0.serialNumber == nil }
                        if needsBackfill {
                            // Nummerierung neu vergeben
                            plan.renumberSessions()

                            // Stats (optional)
                            retitledSessions += plan.treatmentSessions.count

                            // zurückschreiben
                            therapy.therapyPlans[plIdx] = plan
                            patientChanged = true
                        }
                    }

                    patient.therapies[tIdx] = therapy
                }

                if patientChanged {
                    changedCount += 1
                    // Persistenz + Change-Log handled intern
                    await patientStore.updatePatientAsync(patient)
                }
            }
        }
    }
}
