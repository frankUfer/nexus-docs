//
//  DeriveSequencePattern.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.06.25.
//

import Foundation

// Ableitung des sequenziellen Musters aus mehreren geplanten Terminen
func deriveSequencePattern(from sessions: [TreatmentSessions]) -> NextSessionPattern? {
    guard sessions.count >= 2 else { return nil }

    let sorted = sessions.sorted { $0.startTime < $1.startTime }
    let calendar = Calendar.current

    let weekdays = sorted.map { calendar.component(.weekday, from: $0.startTime) }
    let times = sorted.map { $0.startTime.timeOnlyRoundedTo5Min }

    let weekDiffs = zip(sorted.dropFirst(), sorted).map {
        calendar.dateComponents([.weekOfYear], from: $1.startTime.onlyDate, to: $0.startTime.onlyDate).weekOfYear ?? 1
    }
        
    let lastDiff = weekDiffs.last ?? 1
    let intervalWeeks = weekDiffs + [lastDiff]

    return NextSessionPattern(
        weekdays: weekdays,
        startTimes: times,
        intervalWeeks: intervalWeeks
    )
}
