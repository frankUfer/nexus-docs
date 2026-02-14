//
//  CalendarDay.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import Foundation

/// Represents a single calendar day with additional metadata such as week number, weekday, and tags.
struct CalendarDay: Identifiable, Codable {
    // MARK: - Identifiable

    /// The unique identifier for the day (the date itself).
    var id: Date { date }

    // MARK: - Data

    /// The specific date represented by this calendar day (e.g., 2025-04-14).
    var date: Date

    /// The ISO 8601 calendar week number for this date.
    var isoWeek: Int

    /// The weekday as an integer (1 = Sunday, 2 = Monday, ...).
    var weekday: Int

    /// Indicates if the day is a weekend (true for Saturday or Sunday).
    var isWeekend: Bool

    /// Additional tags for the day (e.g., holidays, "weekend").
    var tags: [String] = []
}


