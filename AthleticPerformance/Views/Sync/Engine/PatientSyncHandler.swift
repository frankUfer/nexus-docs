import Foundation

/// Merges patient/session/assessment/invoice changes from pull into local patient.json.
/// Saves directly via PatientStore, bypassing updatePatientAsync to avoid re-triggering
/// the outbound queue (which would cause an infinite sync loop).
enum PatientSyncHandler {

    /// Applies a pulled change to the local patient store.
    /// Returns true if the change was applied successfully.
    @MainActor
    static func apply(change: SyncPullChange, patientStore: PatientStore) async -> Bool {
        guard let patientId = change.patientId else { return false }

        // Load existing patient or create a minimal one for new patients
        var patient: Patient
        if let existing = patientStore.getPatient(by: patientId) {
            patient = existing
        } else if change.entityType == .patient && change.operation == "create" {
            // New patient arriving from server — decode directly
            return await applyNewPatient(change: change, patientStore: patientStore)
        } else {
            // Change for a patient we don't have locally — skip
            return false
        }

        let merged = EntityMerger.merge(change: change, into: &patient)
        if merged {
            // Save directly — bypass updatePatientAsync to avoid re-triggering outbound queue
            patientStore.applyPatient(patient)
            await patientStore.savePatientAsync(patient)
        }
        return merged
    }

    // MARK: - New Patient from Server

    @MainActor
    private static func applyNewPatient(change: SyncPullChange, patientStore: PatientStore) async -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let rawData = change.data.mapValues(\.value)
        guard let jsonData = try? JSONSerialization.data(withJSONObject: rawData),
              let patient = try? decoder.decode(Patient.self, from: jsonData)
        else { return false }

        patientStore.applyPatient(patient)
        await patientStore.savePatientAsync(patient)
        return true
    }
}
