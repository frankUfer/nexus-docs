import Foundation
import ZIPFoundation

// MARK: - Data Model

struct BackupFileInfo: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let name: String
    let size: String
    let date: Date
}

// MARK: - Errors

enum BackupRestoreError: LocalizedError {
    case documentsNotFound
    case noFilesToBackup
    case backupFailed(String)
    case restoreFailed(String)
    case noRestoreFileSelected

    var errorDescription: String? {
        switch self {
        case .documentsNotFound:
            return NSLocalizedString("errorDocumentFolderNotFound",
                                     comment: "Could not find document directory")
        case .noFilesToBackup:
            return NSLocalizedString("errorNoFilesToBackup",
                                     comment: "No files found to backup")
        case .backupFailed(let detail):
            return String(format: NSLocalizedString("errorBackupFailed",
                                                     comment: "Backup failed: %@"), detail)
        case .restoreFailed(let detail):
            return String(format: NSLocalizedString("errorRestoreFailed",
                                                     comment: "Restore failed: %@"), detail)
        case .noRestoreFileSelected:
            return NSLocalizedString("errorNoRestoreFileSelected",
                                     comment: "No restore file selected")
        }
    }
}

// MARK: - Manager

class BackupRestoreManager: ObservableObject {

    // MARK: Published State

    @Published var isProcessing = false
    @Published var statusMessage = ""
    @Published var lastError: String?
    @Published var availableFiles: [BackupFileInfo] = []

    // MARK: Constants

    /// Prefix used for backup zip files. Used to identify and filter them.
    static let backupPrefix = "backup_"

    // MARK: Computed Paths

    var documentsURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // MARK: Helper

    /// Returns true if the filename is a backup zip file created by this app.
    static func isBackupFile(_ name: String) -> Bool {
        name.hasPrefix(backupPrefix) && name.hasSuffix(".zip")
    }

    // MARK: - Scan

    /// Scans the Documents folder for backup_*.zip files and updates `availableFiles`.
    func scanFiles() {
        guard let docsURL = documentsURL else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: docsURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file

            availableFiles = contents
                .filter { Self.isBackupFile($0.lastPathComponent) }
                .compactMap { fileURL -> BackupFileInfo? in
                    let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let size = values?.fileSize ?? 0
                    let date = values?.creationDate ?? Date.distantPast
                    return BackupFileInfo(
                        url: fileURL,
                        name: fileURL.deletingPathExtension().lastPathComponent,
                        size: formatter.string(fromByteCount: Int64(size)),
                        date: date
                    )
                }
                .sorted { $0.date > $1.date }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Backup

    func performBackup() {
        guard !isProcessing else { return }

        isProcessing = true
        statusMessage = NSLocalizedString("backupInProgress", comment: "Backup in progress…")
        lastError = nil

        let docsURL = self.documentsURL

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let docsURL else {
                    throw BackupRestoreError.documentsNotFound
                }

                let fm = FileManager.default

                // Timestamp
                let dateFmt = DateFormatter()
                dateFmt.dateFormat = "yyyy-MM-dd_HHmmss"
                let timestamp = dateFmt.string(from: Date())
                let backupName = "\(BackupRestoreManager.backupPrefix)\(timestamp)"

                // Staging directory inside tmp
                let tempBase = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let stagingDir = tempBase.appendingPathComponent(backupName)
                try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

                // Copy every item in Documents except existing backup zips
                let contents = try fm.contentsOfDirectory(
                    at: docsURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )

                let itemsToBackup = contents.filter {
                    !BackupRestoreManager.isBackupFile($0.lastPathComponent)
                }

                guard !itemsToBackup.isEmpty else {
                    throw BackupRestoreError.noFilesToBackup
                }

                for item in itemsToBackup {
                    let dest = stagingDir.appendingPathComponent(item.lastPathComponent)
                    try fm.copyItem(at: item, to: dest)
                }

                // Create zip archive directly in Documents
                let zipURL = docsURL.appendingPathComponent("\(backupName).zip")
                if fm.fileExists(atPath: zipURL.path) {
                    try fm.removeItem(at: zipURL)
                }
                try fm.zipItem(at: stagingDir, to: zipURL)

                // Clean up staging
                try? fm.removeItem(at: tempBase)

                // Report success
                await MainActor.run { [weak self] in
                    self?.statusMessage = NSLocalizedString("backupComplete",
                                                            comment: "Backup created successfully!")
                    self?.isProcessing = false
                    self?.scanFiles()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.statusMessage = NSLocalizedString("backupFailed",
                                                            comment: "Backup failed")
                    self?.isProcessing = false
                }
            }
        }
    }

    // MARK: - Restore

    func performRestore(from zipURL: URL) {
        guard !isProcessing else { return }

        isProcessing = true
        statusMessage = NSLocalizedString("restoreInProgress", comment: "Restore in progress…")
        lastError = nil

        let docsURL = self.documentsURL

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let docsURL else {
                    throw BackupRestoreError.documentsNotFound
                }

                let fm = FileManager.default

                // 1. Extract zip to a temporary directory
                let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
                try fm.unzipItem(at: zipURL, to: tempDir)

                // 2. Locate the backup subfolder inside the extracted archive.
                let extracted = try fm.contentsOfDirectory(
                    at: tempDir,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                )

                let sourceDir: URL
                if let backupFolder = extracted.first(where: {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }) {
                    sourceDir = backupFolder
                } else {
                    // Flat zip – files are directly in tempDir
                    sourceDir = tempDir
                }

                // 3. Delete current Documents contents except backup zip files
                let currentContents = try fm.contentsOfDirectory(
                    at: docsURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )

                for item in currentContents {
                    // Preserve all backup zip files
                    if BackupRestoreManager.isBackupFile(item.lastPathComponent) { continue }
                    try fm.removeItem(at: item)
                }

                // 4. Copy restored items into Documents
                let restoredItems = try fm.contentsOfDirectory(
                    at: sourceDir,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )

                for item in restoredItems {
                    let dest = docsURL.appendingPathComponent(item.lastPathComponent)
                    // Skip if a backup zip with the same name already exists
                    if fm.fileExists(atPath: dest.path) { continue }
                    try fm.copyItem(at: item, to: dest)
                }

                // 5. Ensure critical subdirectories exist after restore
                let resourcesURL = docsURL
                    .appendingPathComponent("resources")
                let parameterURL = resourcesURL
                    .appendingPathComponent("parameter")

                if !fm.fileExists(atPath: parameterURL.path) {
                    try fm.createDirectory(at: parameterURL, withIntermediateDirectories: true)
                }

                // 6. Clean up temp
                try? fm.removeItem(at: tempDir)

                await MainActor.run { [weak self] in
                    self?.statusMessage = NSLocalizedString("restoreComplete",
                                                            comment: "Restore completed successfully!")
                    self?.isProcessing = false
                    self?.scanFiles()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.statusMessage = NSLocalizedString("restoreFailed",
                                                            comment: "Restore failed")
                    self?.isProcessing = false
                }
            }
        }
    }

    // MARK: - Delete a backup zip

    func deleteBackup(_ file: BackupFileInfo) {
        do {
            try FileManager.default.removeItem(at: file.url)
            scanFiles()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
