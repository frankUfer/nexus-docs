//
//  Date.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import Foundation

extension Date {
    func stripTime() -> Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var onlyDate: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var timeOnly: DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: self)
    }
        
    var timeOnlyRoundedTo5Min: DateComponents {
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.hour, .minute], from: self)
            let roundedMin = Int(round(Double(comps.minute ?? 0) / 5.0)) * 5 % 60
            return DateComponents(hour: comps.hour, minute: roundedMin)
        }
    
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
}

extension Date {
    func endOfMonth(using calendar: Calendar = .current) -> Date {
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: self))!
        return calendar.date(byAdding: .day, value: -1, to: startOfNextMonth)!
    }
}
