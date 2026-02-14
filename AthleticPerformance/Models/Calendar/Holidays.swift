//
//  Holidays.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import Foundation

struct LocalizedHolidayName: Codable, Hashable {
    let de: String
    let en: String
}

struct HolidayEntry: Codable, Hashable {
    let holiday: LocalizedHolidayName
    let month: Int
    let day: Int
}

struct HolidayCalendarEntry: Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var name: String
}

extension HolidayEntry {
    func localizedName(locale: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        switch locale {
        case "de": return holiday.de
        default: return holiday.en
        }
    }
}
