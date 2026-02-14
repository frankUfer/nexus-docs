//
//  SettingsOption.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import Foundation

enum SettingsOption: String, CaseIterable, Identifiable, Hashable {
    case practiceInfo
    case insurances
    case specialties
    case availability
    

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .practiceInfo: return NSLocalizedString("settingsPracticeInfo", comment: "Practice Info")
        case .insurances: return NSLocalizedString("settingsInsurances", comment: "Insurances")
        case .specialties: return NSLocalizedString("settingsSpecialties", comment: "Specialties")
        case .availability: return NSLocalizedString("settingsAvailability", comment: "Availability")
        }
    }

    var icon: String {
        switch self {
        case .practiceInfo: return "building.2"
        case .insurances: return "shield"
        case .specialties: return "staroflife"
        case .availability: return "calendar"
        }
    }
}
