//
//  SettingsMenuView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import SwiftUI

struct SettingsMenuView: View {
    @Binding var selectedSettingsOption: SettingsOption?

    var body: some View {
        List(selection: $selectedSettingsOption) {
            ForEach(SettingsOption.allCases) { option in
                Label(option.localizedLabel, systemImage: option.icon)
                    .tag(option)
            }
        }
        .navigationTitle(NSLocalizedString("settingsMenuTitle", comment: "Settings"))
    }
}
