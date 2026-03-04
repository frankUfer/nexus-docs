import SwiftUI

enum SyncOption: String, CaseIterable, Identifiable, Hashable {
    case status
    case backup
    case restore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .status:
            return NSLocalizedString("syncSynchronisation", comment: "Synchronisation")
        case .backup:
            return NSLocalizedString("backupTitle", comment: "Create Backup")
        case .restore:
            return NSLocalizedString("restoreTitle", comment: "Restore Data")
        }
    }

    var icon: String {
        switch self {
        case .status:
            return "arrow.triangle.2.circlepath"
        case .backup:
            return "arrow.up.doc.on.clipboard"
        case .restore:
            return "arrow.down.doc"
        }
    }
}
