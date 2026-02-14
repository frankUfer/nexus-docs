import SwiftUI

enum SyncOption: String, CaseIterable, Identifiable, Hashable {
    case status
    case sync
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .status:
            return NSLocalizedString("syncStatus", comment: "Status")
        case .sync:
            return NSLocalizedString("syncNow", comment: "Sync Now")
        case .settings:
            return NSLocalizedString("syncSettings", comment: "Settings")
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
        }
    }
}
