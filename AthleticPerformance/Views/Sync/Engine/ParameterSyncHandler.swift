import Foundation

/// Applies server parameter updates to local files in Documents/resources/parameter/.
/// Server parameters always win (three-tier conflict resolution).
/// This is the server-side complement to the "seed once" strategy in SetupAppDirectories.
enum ParameterSyncHandler {

    /// Applies a pulled parameter change to local parameter files and reloads AppGlobals.
    /// Returns true if the change was applied successfully.
    @MainActor
    static func apply(change: SyncPullChange) -> Bool {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return false }
        let paramDir = docs.appendingPathComponent("resources/parameter", isDirectory: true)

        switch change.entityType {
        case .treatmentType:
            return applyTreatmentType(change: change, paramDir: paramDir)

        case .icdCode:
            return applyToFile(change: change, filename: "diagnoseReferenceData.json", paramDir: paramDir)

        case .systemConfig:
            return applyToFile(change: change, filename: "practiceInfo.json", paramDir: paramDir)

        case .referenceData:
            return applyReferenceData(change: change, paramDir: paramDir)

        default:
            return false
        }
    }

    /// Reloads all parameters into AppGlobals after a parameter file has been updated.
    @MainActor
    static func reloadParameters() {
        _ = loadAppParameters()
    }

    // MARK: - Treatment Type

    private static func applyTreatmentType(change: SyncPullChange, paramDir: URL) -> Bool {
        // Treatment types map to practiceInfo.json (TreatmentServices section)
        return applyToFile(change: change, filename: "practiceInfo.json", paramDir: paramDir)
    }

    // MARK: - Reference Data

    private static func applyReferenceData(change: SyncPullChange, paramDir: URL) -> Bool {
        // Reference data sub-type determines which local file to update.
        // Check data for a "reference_type" or "sub_type" key to route appropriately.
        let data = change.data

        if let subType = data["reference_type"]?.value as? String ?? data["sub_type"]?.value as? String {
            let filename: String?
            switch subType {
            case "joints": filename = "joints.json"
            case "muscle_groups": filename = "muscleGroups.json"
            case "tissues": filename = "tissues.json"
            case "tissue_states": filename = "tissueStates.json"
            case "pain_qualities": filename = "painQualities.json"
            case "pain_structures": filename = "painStructures.json"
            case "joint_movement_patterns": filename = "jointMovementPatterns.json"
            case "assessments": filename = "assessments.json"
            case "end_feelings": filename = "endFeelings.json"
            case "anamnesis": filename = "anamnesis.json"
            case "specialties": filename = "specialties.json"
            case "insurances": filename = "insurances.json"
            case "public_addresses": filename = "publicAddresses.json"
            case "physio_reference_data": filename = "physioReferenceData.json"
            default: filename = nil
            }

            if let filename {
                return applyToFile(change: change, filename: filename, paramDir: paramDir)
            }
        }

        return false
    }

    // MARK: - Generic File Writer

    private static func applyToFile(change: SyncPullChange, filename: String, paramDir: URL) -> Bool {
        let fileURL = paramDir.appendingPathComponent(filename)
        let rawData = change.data.mapValues(\.value)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: rawData, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }

        do {
            try jsonData.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
