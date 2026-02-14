import SwiftUI

struct SyncMenuView: View {
    @Binding var selectedSyncOption: SyncOption?

    var body: some View {
        List(SyncOption.allCases, selection: $selectedSyncOption) { option in
            Label(option.label, systemImage: option.icon)
                .tag(option)
        }
        .navigationTitle(NSLocalizedString("syncTitle", comment: "Data Transfer"))
    }
}
