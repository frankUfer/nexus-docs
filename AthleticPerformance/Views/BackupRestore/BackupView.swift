import SwiftUI

struct BackupView: View {
    @StateObject private var manager = BackupRestoreManager()
    @State private var showDeleteConfirmation = false
    @State private var fileToDelete: BackupFileInfo?

    var body: some View {
        Form {
            // MARK: Instructions
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(NSLocalizedString("backupTitle", comment: "Create Backup"),
                          systemImage: "arrow.up.doc.on.clipboard")
                        .font(.headline)

                    Text(NSLocalizedString("backupInstructions",
                         comment: "Creates a ZIP archive of all application data in the Documents folder. Connect your iPad to your Mac via USB cable and use Finder to copy the backup file to your computer."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // MARK: Backup Action
            Section {
                Button {
                    manager.performBackup()
                } label: {
                    HStack {
                        Spacer()
                        if manager.isProcessing {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(manager.statusMessage)
                        } else {
                            Image(systemName: "arrow.up.doc.on.clipboard")
                            Text(NSLocalizedString("backupCreateButton", comment: "Create Backup"))
                        }
                        Spacer()
                    }
                    .font(.headline)
                    .padding(.vertical, 4)
                }
                .disabled(manager.isProcessing)
            }

            // MARK: Status
            if let error = manager.lastError {
                Section {
                    Label {
                        Text(error)
                            .foregroundStyle(.red)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            } else if !manager.isProcessing && manager.statusMessage == NSLocalizedString("backupComplete", comment: "") {
                Section {
                    Label {
                        Text(manager.statusMessage)
                            .foregroundStyle(.green)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            // MARK: Existing Backups
            Section {
                if manager.availableFiles.isEmpty {
                    Text(NSLocalizedString("backupNoFilesFound",
                         comment: "No backup files found."))
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(manager.availableFiles) { file in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.body)
                                HStack(spacing: 12) {
                                    Text(file.size)
                                    Text(file.date, style: .date)
                                    Text(file.date, style: .time)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                fileToDelete = file
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text(NSLocalizedString("backupExistingFiles", comment: "Backup Files"))
            } footer: {
                Text(NSLocalizedString("backupFinderHint",
                     comment: "Connect your iPad via USB and open Finder → iPad → Files → [App Name] to copy the backup files to your Mac."))
            }
        }
        .navigationTitle(NSLocalizedString("backupTitle", comment: "Create Backup"))
        .task {
            manager.scanFiles()
        }
        .refreshable {
            manager.scanFiles()
        }
        .alert(NSLocalizedString("backupDeleteConfirmTitle", comment: "Delete Backup?"),
               isPresented: $showDeleteConfirmation,
               presenting: fileToDelete) { file in
            Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                manager.deleteBackup(file)
            }
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
        } message: { file in
            Text(String(format: NSLocalizedString("backupDeleteConfirmMessage",
                 comment: "Are you sure you want to delete \"%@\"?"), file.name))
        }
    }
}
