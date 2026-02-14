import Foundation

/// One-time migration that re-encodes all on-disk patient.json and change-log files
/// so that legacy Int therapist IDs become deterministic UUIDs.
///
/// The custom `init(from:)` decoders on each model already handle Int→UUID conversion,
/// so this migrator simply decodes → re-encodes every file, letting the decoders do the work.
/// A marker file prevents re-running.
enum TherapistIdMigrator {

    private static let markerFileName = "therapist_id_migration_complete.json"

    static func runIfNeeded() {
        let fm = FileManager.default
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let syncDir = docsURL.appendingPathComponent("sync", isDirectory: true)
        let markerFile = syncDir.appendingPathComponent(markerFileName)

        // Already migrated?
        guard !fm.fileExists(atPath: markerFile.path) else { return }

        let patientsDir = docsURL.appendingPathComponent("patients", isDirectory: true)
        let paramDir = docsURL.appendingPathComponent("resources/parameter", isDirectory: true)

        // 1) Migrate patient.json files
        migratePatientFiles(in: patientsDir, fm: fm)

        // 2) Migrate change-log files
        migrateChangeLogs(in: patientsDir, fm: fm)

        // 3) Migrate availability files (rename Int-based to UUID-based)
        migrateAvailabilityFiles(in: docsURL, fm: fm)

        // 4) Migrate practiceInfo.json (therapist IDs inside)
        migratePracticeInfo(paramDir: paramDir, fm: fm)

        // 5) Migrate therapist.json reference file
        migrateTherapistReference(paramDir: paramDir, fm: fm)

        // Write marker
        try? fm.createDirectory(at: syncDir, withIntermediateDirectories: true)
        let marker = try? JSONEncoder().encode(["migratedAt": ISO8601DateFormatter().string(from: Date())])
        try? marker?.write(to: markerFile, options: .atomic)
    }

    // MARK: - Patient files

    private static func migratePatientFiles(in patientsDir: URL, fm: FileManager) {
        guard let folders = try? fm.contentsOfDirectory(at: patientsDir, includingPropertiesForKeys: nil) else { return }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        for folder in folders {
            let fileURL = folder.appendingPathComponent("patient.json")
            guard fm.fileExists(atPath: fileURL.path) else { continue }
            guard let data = try? Data(contentsOf: fileURL) else { continue }

            // Decode with backward-compat decoders (Int→UUID happens here)
            guard let file = try? decoder.decode(PatientFile.self, from: data) else { continue }

            // Re-encode with UUID values
            guard let newData = try? encoder.encode(file) else { continue }
            try? newData.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Change logs

    private static func migrateChangeLogs(in patientsDir: URL, fm: FileManager) {
        guard let folders = try? fm.contentsOfDirectory(at: patientsDir, includingPropertiesForKeys: nil) else { return }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        for folder in folders {
            let changesDir = folder.appendingPathComponent("changes", isDirectory: true)
            guard let files = try? fm.contentsOfDirectory(at: changesDir, includingPropertiesForKeys: nil) else { continue }

            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file) else { continue }
                guard let log = try? decoder.decode(ChangeLog.self, from: data) else { continue }
                guard let newData = try? encoder.encode(log) else { continue }
                try? newData.write(to: file, options: .atomic)
            }
        }
    }

    // MARK: - Availability files

    private static func migrateAvailabilityFiles(in docsURL: URL, fm: FileManager) {
        // Availability files live at Documents/availability_<id>.json
        guard let files = try? fm.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil) else { return }

        for file in files where file.lastPathComponent.hasPrefix("availability_") && file.pathExtension == "json" {
            let name = file.deletingPathExtension().lastPathComponent
            let suffix = name.replacingOccurrences(of: "availability_", with: "")

            // If suffix is a number (legacy Int ID), rename to UUID-based filename
            if let intId = Int(suffix) {
                let uuid = therapistUUIDFromInt(intId)
                let newFile = docsURL.appendingPathComponent("availability_\(uuid.uuidString).json")
                if !fm.fileExists(atPath: newFile.path) {
                    try? fm.moveItem(at: file, to: newFile)
                }
            }
        }
    }

    // MARK: - Practice info

    private static func migratePracticeInfo(paramDir: URL, fm: FileManager) {
        let fileURL = paramDir.appendingPathComponent("practiceInfo.json")
        guard fm.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        guard let file = try? decoder.decode(PracticeInfoFile.self, from: data) else { return }
        guard let newData = try? encoder.encode(file) else { return }
        try? newData.write(to: fileURL, options: .atomic)
    }

    // MARK: - Therapist reference

    private static func migrateTherapistReference(paramDir: URL, fm: FileManager) {
        let fileURL = paramDir.appendingPathComponent("therapist.json")
        guard fm.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        guard let file = try? decoder.decode(TherapistReferenceFile.self, from: data) else { return }
        guard let newData = try? encoder.encode(file) else { return }
        try? newData.write(to: fileURL, options: .atomic)
    }
}
