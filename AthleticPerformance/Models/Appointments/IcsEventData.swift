//
//  IcsEventData.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 05.06.25.
//

import Foundation

struct IcsEventData {
    let uid: String
    let start: Date
    let end: Date
    let summary: String
    let description: String?
    let location: String?
    let attendeeEmails: [String]?
    let alertMinutesBefore: Int?
    let sequence: Int?
}

func mapTreatmentSessionsToIcsEvents(_ sessions: [TreatmentSessions]) -> [IcsEventData] {
    return sessions.map { session in
        let start = combine(date: session.date, time: session.startTime)
        let end = combine(date: session.date, time: session.endTime)
        
        let locationString: String = {
            var components = [
                session.address.street,
                "\(session.address.postalCode) \(session.address.city)"
            ]
            components.append(session.address.country)
            
            return components.joined(separator: ", ")
        }()

        let uid = session.icsUid ?? session.id.uuidString

        return IcsEventData(
            uid: uid,
            start: start,
            end: end,
            summary: AppGlobals.shared.practiceInfo.name,
            description: session.title,
            location: locationString,
            attendeeEmails: nil,
            alertMinutesBefore: AppGlobals.shared.alertMinutesBefore,
            sequence: 0
        )
    }
}

private func combine(date: Date, time: Date) -> Date {
    let calendar = Calendar.current
    let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
    
    var combined = DateComponents()
    combined.year = dateComponents.year
    combined.month = dateComponents.month
    combined.day = dateComponents.day
    combined.hour = timeComponents.hour
    combined.minute = timeComponents.minute
    combined.second = timeComponents.second
    
    return calendar.date(from: combined)!
}
