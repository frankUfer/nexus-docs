import SwiftUI

enum SyncOption: String, CaseIterable, Identifiable, Hashable {
    case backup
    case restore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .backup:
            return NSLocalizedString("syncBackup", comment: "Backup")
        case .restore:
            return NSLocalizedString("syncRestore", comment: "Restore")
        }
    }

    var icon: String {
        switch self {
        case .backup:
            return "arrow.up.doc.on.clipboard"
        case .restore:
            return "arrow.down.doc"
        }
    }
}
