//
//  HolidayStore.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import Foundation
import SwiftUI

class HolidayStore: ObservableObject {
    @Published var holidays: [HolidayCalendarEntry] = []

    private var calendar = Calendar.current
    private var currentYear: Int

    init(for year: Int = Calendar.current.component(.year, from: Date())) {
        self.currentYear = year
        loadHolidays(for: year)
    }

    func loadHolidays(for year: Int) {
        holidays = CalendarBuilder.generateHolidays(for: year)
        currentYear = year
    }

    func holiday(on date: Date) -> HolidayCalendarEntry? {
        return holidays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func holidays(in range: ClosedRange<Date>) -> [HolidayCalendarEntry] {
        holidays.filter { range.contains($0.date) }
    }

    func refreshIfNeeded(for date: Date) {
        let year = calendar.component(.year, from: date)
        if year != currentYear {
            loadHolidays(for: year)
        }
    }
}
