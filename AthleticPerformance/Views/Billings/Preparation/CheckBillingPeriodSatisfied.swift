//
//  CheckBillingPeriodSatisfied.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 20.06.25.
//

import Foundation

func checkBillingPeriodSatisfied(for plan: TherapyPlan, billingPeriod: BillingPeriod, upTo date: Date) -> Bool {
    let calendar = Calendar.current

    switch billingPeriod {
    case .session, .custom:
        return true

    case .end:
        guard plan.isCompleted else {
            return false
        }
        let lastSessionDate = plan.treatmentSessions.map(\.date).max() ?? .distantFuture
        let isAfterLastSession = date >= lastSessionDate
        return isAfterLastSession

    case .monthly, .quarterly:
        let periodStart: Date
        let periodEnd: Date

        switch billingPeriod {
        case .monthly:
            periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            periodEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: periodStart)!

        case .quarterly:
            let components = calendar.dateComponents(in: TimeZone.current, from: date)
            let year = components.year!
            let month = components.month!
            let quarter = ((month - 1) / 3) + 1

            let startMonth = (quarter - 1) * 3 + 1

            periodStart = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1))!
            periodEnd = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: periodStart)!

        default:
            return true
        }

        let sessionsInPeriod = plan.treatmentSessions.filter {
            $0.date >= periodStart && $0.date <= periodEnd
        }

        let allClosed = sessionsInPeriod.allSatisfy { $0.isDone || $0.isInvoiced }

        let isEndOfMonth = calendar.isDate(date, equalTo: periodEnd, toGranularity: .day)
        let isQuarterEnd = calendar.isDate(date, equalTo: periodEnd, toGranularity: .day)

        switch billingPeriod {
        case .monthly:
            let result = isEndOfMonth && allClosed
            return result

        case .quarterly:
            let result = isQuarterEnd && allClosed
            return result

        default:
            return true
        }
    }
}
