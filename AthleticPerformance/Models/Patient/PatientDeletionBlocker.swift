//
//  PatientDeletionBlocker.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 07.10.25.
//

import Foundation

// MARK: - Reusable deletion policy

/// Neutrale Gründe, die das Löschen verhindern (UI lokalisiert später).
enum PatientDeletionBlocker: Hashable {
    case contractPDF
    case therapyAgreement
    case diagnoses
    case findings
    case therapyPlans       // Plan existiert (auch ohne Sessions)
    case sessions           // mind. 1 Session vorhanden
}

struct PatientDeletionPolicy {

    /// Liefert die Blocker für einen Patienten.
    /// - Parameter hasContractPDF: Callback, damit die Policy nichts über Dateisystem/Store wissen muss.
    static func blockers(
        for patient: Patient,
        hasContractPDF: (UUID) -> Bool
    ) -> Set<PatientDeletionBlocker> {
        var out: Set<PatientDeletionBlocker> = []

        // 1) Datei-basierter Vertrag?
        if hasContractPDF(patient.id) {
            out.insert(.contractPDF)
        }

        // 2) Inhalte in Therapien?
        let therapies = patient.therapies.compactMap { $0 }
        guard !therapies.isEmpty else {
            // keine Therapien → bisher kein weiterer Blocker
            return out
        }

        for therapy in therapies {
            if therapy.isAgreed { out.insert(.therapyAgreement) }
            if !therapy.diagnoses.isEmpty { out.insert(.diagnoses) }
            if !therapy.findings.isEmpty { out.insert(.findings) }

            // Pläne/Sessions prüfen
            for plan in therapy.therapyPlans {
                if !plan.treatmentSessions.isEmpty {
                    out.insert(.sessions)
                } else {
                    // auch „leere“ Planung (Services, Titel, etc.) blockiert das Löschen
                    if !(plan.treatmentServiceIds.isEmpty)
                        || !(plan.title ?? "").isEmpty
                        || plan.diagnosisId != nil
                    {
                        out.insert(.therapyPlans)
                    }
                }
            }
        }

        return out
    }

    /// True, wenn keinerlei Blocker vorliegen.
    static func canDelete(
        _ patient: Patient,
        hasContractPDF: (UUID) -> Bool
    ) -> Bool {
        blockers(for: patient, hasContractPDF: hasContractPDF).isEmpty
    }
}
