import SwiftUI

enum SyncOption: String, CaseIterable, Identifiable, Hashable {
    case status
    case sync
    case settings
    case backup
    case restore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .status:
            return NSLocalizedString("syncStatus", comment: "Status")
        case .sync:
            return NSLocalizedString("syncNow", comment: "Sync Now")
        case .settings:
            return NSLocalizedString("syncSettings", comment: "Settings")
        case .backup:
            return NSLocalizedString("backupTitle", comment: "Create Backup")
        case .restore:
            return NSLocalizedString("restoreTitle", comment: "Restore Data")
        }
    }

    var icon: String {
        switch self {
        case .status:
            return "chart.bar.doc.horizontal"
        case .sync:
            return "arrow.triangle.2.circlepath"
        case .settings:
            return "gearshape.2"
        case .backup:
            return "arrow.up.doc.on.clipboard"
        case .restore:
            return "arrow.down.doc"
        }
    }
}
