//
//  PatientValidator.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.03.25.
//

import Foundation

struct PatientValidator {
    
    @MainActor static func validate(
        patient: Patient,
        patientStore: PatientStore,
        editingPatientID: UUID? = nil
    ) -> String? {
        
        let trimmedFirstname = patient.firstname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastname = patient.lastname.trimmingCharacters(in: .whitespacesAndNewlines)

        // 🧪 Pflichtfelder prüfen
        if trimmedFirstname.isEmpty {
            return NSLocalizedString("First_Name_Required", comment: "")
        }
        if trimmedLastname.isEmpty {
            return NSLocalizedString("Last_Name_Required", comment: "")
        }

        // 🔁 Dublettenprüfung
        let tempPatient = Patient(
            id: editingPatientID ?? UUID(),
            title: patient.title,
            firstname: trimmedFirstname,
            lastname: trimmedLastname,
            birthdate: patient.birthdate,
            sex: patient.sex,
            insuranceStatus: patient.insuranceStatus,
            insurance: nil,
            insuranceNumber: nil,
            familyDoctor: nil,
            anamnesis: nil,
            therapies: [],
            isActive: true,
            addresses: [],
            phoneNumbers: [],
            emailAddresses: [],
            emergencyContacts: [],
            createdDate: .distantPast,
            changedDate: .distantPast
        )

        func isDuplicatePatient(_ newPatient: Patient, in list: [Patient], excludingID: UUID?) -> Bool {
            list.contains {
                $0.id != excludingID && $0.isDuplicate(of: newPatient)
            }
        }
        
        if isDuplicatePatient(tempPatient, in: patientStore.patients, excludingID: editingPatientID) {
            return NSLocalizedString("Duplicate_Patient", comment: "")
        }

        // ☎️ Telefonnummern prüfen
        for phone in patient.phoneNumbers where !phone.value.isEmpty {
            if !isValidPhoneNumber(phone.value) {
                return NSLocalizedString("Invalid_Phone", comment: "")
            }
        }

        // 📧 E-Mail-Adressen prüfen
        for email in patient.emailAddresses where !email.value.isEmpty {
            if !isValidEmail(email.value) {
                return NSLocalizedString("Invalid_Email", comment: "")
            }
        }

        return nil // ✅ Alles gültig
    }
}

extension Patient {
    /// Vergleicht die inhaltlichen Felder zur Dublettenprüfung, ignoriert technische Metafelder.
    func isDuplicate(of other: Patient) -> Bool {
        return firstname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == other.firstname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() &&
               lastname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == other.lastname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() &&
               birthdate == other.birthdate &&
               sex == other.sex
    }
}
