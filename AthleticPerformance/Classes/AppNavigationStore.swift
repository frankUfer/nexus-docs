//
//  AppNavigationStore.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 28.06.25.
//

import Foundation

final class AppNavigationStore: ObservableObject {
    @Published var selectedMainMenu: MainMenu? = .appointments
    @Published var selectedPatientID: UUID? = nil
}
