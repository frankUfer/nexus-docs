//
//  ContentView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.03.25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        //AppNavigationContainer()
        AppNavigationContainer()
            .environmentObject(AppGlobals.shared)
    }
}
