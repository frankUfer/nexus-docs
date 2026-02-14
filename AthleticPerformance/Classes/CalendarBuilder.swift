//
//  CalendarBuilder.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import Foundation

class CalendarBuilder {
    static func generateHolidays(for year: Int) -> [HolidayCalendarEntry] {
        var calendar = Calendar(identifier: .gregorian)
        
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"

        let calendarLocale: Locale
        if preferredLanguage.hasPrefix("de") {
            calendarLocale = Locale(identifier: "de_DE")
        } else if preferredLanguage.hasPrefix("en") {
            calendarLocale = Locale(identifier: "en_US")
        } else {
            calendarLocale = Locale(identifier: "en_US")
        }

        calendar.locale = calendarLocale
        calendar.timeZone = TimeZone.current

        func date(_ day: Int, _ month: Int) -> Date {
            return calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        func entry(_ date: Date, _ nameKey: String) -> HolidayCalendarEntry {
            return HolidayCalendarEntry(date: date, name: NSLocalizedString(nameKey, comment: "Holiday name"))
        }

        var holidays: [HolidayCalendarEntry] = []

        // 🗓 Feste Feiertage
        holidays.append(contentsOf: [
            entry(date(1, 1), "holiday.new_year"),
            entry(date(1, 5), "holiday.labor_day"),
            entry(date(3, 10), "holiday.german_unity"),
            entry(date(25, 12), "holiday.christmas_day1"),
            entry(date(26, 12), "holiday.christmas_day2")
        ])

        // 🕊 Bewegliche Feiertage
        if let easter = calculateEaster(for: year) {
            holidays.append(contentsOf: [
                entry(calendar.date(byAdding: .day, value: -2, to: easter)!, "holiday.good_friday"),
                entry(easter, "holiday.easter_sunday"),
                entry(calendar.date(byAdding: .day, value: 1, to: easter)!, "holiday.easter_monday"),
                entry(calendar.date(byAdding: .day, value: 39, to: easter)!, "holiday.ascension_day"),
                entry(calendar.date(byAdding: .day, value: 49, to: easter)!, "holiday.pentecost_sunday"),
                entry(calendar.date(byAdding: .day, value: 50, to: easter)!, "holiday.pentecost_monday"),
                entry(calendar.date(byAdding: .day, value: 60, to: easter)!, "holiday.corpus_christi")
            ])
        }

        return holidays.sorted(by: { $0.date < $1.date })
    }

    // 📅 Gaußsche Osterformel
    private static func calculateEaster(for year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }
}
