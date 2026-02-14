//
//  MainMenu.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 21.03.25.
//

import SwiftUI

enum MainMenu: String, CaseIterable, Identifiable {
    case patients = "menuPatients"
    case appointments = "menuAppointments"
    case billing = "menuBilling"
    case sync = "menuSync"
    case settings = "menuSettings"

    var id: String { rawValue }

    var label: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var icon: String {
        switch self {
        case .patients: return "person.3"
        case .appointments: return "calendar"
        case .billing: return "doc.text"
        case .sync: return "arrow.triangle.2.circlepath"
        case .settings: return "gearshape"
        }
    }
}
