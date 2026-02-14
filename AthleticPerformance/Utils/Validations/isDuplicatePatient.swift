//
//  isDuplicatePatient.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.03.25.
//

import Foundation

func isDuplicatePatient(_ patient: Patient, in patients: [Patient], excludingID: UUID? = nil) -> Bool {
    let trimmedFirstname = patient.firstname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let trimmedLastname = patient.lastname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let birthdate = patient.birthdate

    return patients.contains { existing in
        guard existing.id != excludingID else { return false }
        return existing.firstname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedFirstname &&
               existing.lastname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedLastname &&
               existing.birthdate == birthdate
    }
}
