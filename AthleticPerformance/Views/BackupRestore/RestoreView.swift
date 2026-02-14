import SwiftUI

struct RestoreView: View {
    @StateObject private var manager = BackupRestoreManager()
    @State private var selectedFile: BackupFileInfo?
    @State private var showRestoreConfirmation = false
    @EnvironmentObject var patientStore: PatientStore

    var body: some View {
        Form {
            // MARK: Warning
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(NSLocalizedString("restoreTitle", comment: "Restore Data"),
                          systemImage: "arrow.down.doc")
                        .font(.headline)

                    Label {
                        Text(NSLocalizedString("restoreWarning",
                             comment: "Restoring will replace ALL current application data with the contents of the selected backup. This action cannot be undone."))
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)

                    Text(NSLocalizedString("restoreInstructions",
                         comment: "To restore, copy a backup .zip file into the app's Documents folder using Finder (iPad → Files → [App Name]), then tap Scan and select the file to restore from."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // MARK: Scan Button
            Section {
                Button {
                    manager.scanFiles()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(NSLocalizedString("restoreScanButton", comment: "Scan for Backup Files"))
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(manager.isProcessing)
            }

            // MARK: Available Files
            Section {
                if manager.availableFiles.isEmpty {
                    Text(NSLocalizedString("restoreNoFilesFound",
                         comment: "No backup files found. Copy a .zip backup file into the app's Documents folder using Finder."))
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(manager.availableFiles) { file in
                        Button {
                            selectedFile = file
                        } label: {
                            HStack {
                                Image(systemName: selectedFile == file
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(selectedFile == file ? .blue : .secondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 12) {
                                        Text(file.size)
                                        Text(file.date, style: .date)
                                        Text(file.date, style: .time)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text(NSLocalizedString("restoreAvailableFiles", comment: "Available Backup Files"))
            }

            // MARK: Restore Action
            Section {
                Button {
                    showRestoreConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if manager.isProcessing {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(manager.statusMessage)
                        } else {
                            Image(systemName: "arrow.down.doc")
                            Text(NSLocalizedString("restoreButton", comment: "Restore Selected Backup"))
                        }
                        Spacer()
                    }
                    .font(.headline)
                    .padding(.vertical, 4)
                }
                .disabled(selectedFile == nil || manager.isProcessing)
                .tint(.orange)
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
            } else if !manager.isProcessing && manager.statusMessage == NSLocalizedString("restoreComplete", comment: "") {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(manager.statusMessage)
                                .foregroundStyle(.green)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Text(NSLocalizedString("restoreRelaunchHint",
                             comment: "Please close and relaunch the app to load the restored data."))
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("restoreTitle", comment: "Restore Data"))
        .task {
            manager.scanFiles()
        }
        .refreshable {
            manager.scanFiles()
        }
        .alert(NSLocalizedString("restoreConfirmTitle", comment: "Confirm Restore"),
               isPresented: $showRestoreConfirmation) {
            Button(NSLocalizedString("restoreConfirmAction", comment: "Restore"),
                   role: .destructive) {
                if let file = selectedFile {
                    manager.performRestore(from: file.url)
                }
            }
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            if let file = selectedFile {
                Text(String(format: NSLocalizedString("restoreConfirmMessage",
                     comment: "All current data will be permanently replaced with the contents of \"%@\". This cannot be undone. Continue?"),
                     file.name))
            }
        }
    }
}
