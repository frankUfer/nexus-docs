//
//  CalendarViewType.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 16.06.25.
//

import SwiftUI

enum CalendarViewType: String, CaseIterable, Identifiable {
    case day = "day"
    case week = "week"
    case month = "month"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .day:
            return NSLocalizedString("day", comment: "Day")
        case .week:
            return NSLocalizedString("week", comment: "Week")
        case .month:
            return NSLocalizedString("month", comment: "Month")
        }
    }
}
