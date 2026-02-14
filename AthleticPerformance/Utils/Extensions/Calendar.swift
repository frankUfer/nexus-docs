//
//  Calendar.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 14.04.25.
//

import Foundation

extension Calendar {
    func weekDates(containing date: Date) -> [Date] {
        guard let weekInterval = self.dateInterval(of: .weekOfYear, for: date) else { return [] }
        var dates: [Date] = []
        var current = weekInterval.start
        while current < weekInterval.end {
            dates.append(current)
            current = self.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }
}

extension Calendar {
    func monthDates(for date: Date, padded: Bool = true) -> [Date] {
        guard let monthInterval = self.dateInterval(of: .month, for: date),
              let firstWeek = self.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = self.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1)) else {
            return []
        }

        let start = padded ? firstWeek.start : monthInterval.start
        let end = padded ? lastWeek.end : monthInterval.end

        var dates: [Date] = []
        var current = start
        while current < end {
            dates.append(current)
            current = self.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }
}

extension Calendar {
    func combine(date: Date, time: Date) -> Date {
        let datePart = self.dateComponents([.year, .month, .day], from: date)
        let timePart = self.dateComponents([.hour, .minute, .second], from: time)

        var components = DateComponents()
        components.year = datePart.year
        components.month = datePart.month
        components.day = datePart.day
        components.hour = timePart.hour
        components.minute = timePart.minute
        components.second = timePart.second

        return self.date(from: components) ?? date
    }
}

extension Calendar {
    func generateDates(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        var current = start

        while current <= end {
            dates.append(current)
            guard let next = self.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let weekday = component(.weekday, from: date)
        let daysToSubtract = weekday - firstWeekday
        guard let start = date.addingTimeInterval(TimeInterval(-daysToSubtract * 24 * 60 * 60)) as Date? else {
            return startOfDay(for: date)
        }
        return startOfDay(for: start)
    }
}
