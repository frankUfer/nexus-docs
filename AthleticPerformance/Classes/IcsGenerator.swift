//
//  IcsGenerator.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 05.06.25.
//

import SwiftUI
import UniformTypeIdentifiers

final class IcsGenerator {

    // MARK: - ICS as Data

    static func generateCalendarData(events: [IcsEventData], organizerEmail: String, organizerName: String = AppGlobals.shared.practiceInfo.name) -> Data? {
        let string = generateCalendar(events: events, organizerEmail: organizerEmail, organizerName: organizerName)
        return string.data(using: .utf8)
    }

    // MARK: - String Generator (unverändert)

    static func generateCalendar(events: [IcsEventData], organizerEmail: String, organizerName: String) -> String {
        var lines: [String] = []
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//AthleticPerformance//ICS Generator 1.0//DE")
        lines.append("CALSCALE:GREGORIAN")
        lines.append("METHOD:REQUEST")

        for event in events {
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(event.uid)")
            lines.append("DTSTAMP:\(format(date: Date()))")
            lines.append("DTSTART:\(format(date: event.start))")
            lines.append("DTEND:\(format(date: event.end))")
            lines.append("SUMMARY:\(NSLocalizedString("icsEventDescription", comment: "ics event description"))")
            
            if let desc = event.description {
                lines.append("DESCRIPTION:\(desc)")
            }
            if let loc = event.location {
                lines.append("LOCATION:\(loc)")
            }

            lines.append("ORGANIZER;CN=\(organizerName):mailto:\(organizerEmail)")
            
            event.attendeeEmails?.forEach {
                lines.append("ATTENDEE;RSVP=TRUE;PARTSTAT=NEEDS-ACTION:mailto:\($0)")
            }
            
            if let alert = event.alertMinutesBefore {
                lines.append(contentsOf: [
                    "BEGIN:VALARM",
                    "TRIGGER:-PT\(alert)M",
                    "ACTION:DISPLAY",
                    "DESCRIPTION:Erinnerung",
                    "END:VALARM"
                ])
            }

            // ✅ Dynamischer SEQUENCE-Wert (Standard = 0)
            let sequence = event.sequence ?? 0
            lines.append("STATUS:CONFIRMED")
            lines.append("SEQUENCE:\(sequence)")
            lines.append("TRANSP:OPAQUE")
            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }

    static func generateCancellation(
        uid: String,
        start: Date,
        end: Date?,
        summary: String,
        location: String?,
        attendee: String?,
        sequence: Int
    ) -> String {
        let organizerName = AppGlobals.shared.practiceInfo.name
        let organizerEmail = AppGlobals.shared.practiceInfo.email

        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//AthleticPerformance//ICS Generator 1.0//DE",
            "METHOD:CANCEL"
        ]

        lines.append(contentsOf: [
            "BEGIN:VEVENT",
            "UID:\(uid)",
            "SEQUENCE:\(sequence)",
            "STATUS:CANCELLED",
            "DTSTAMP:\(format(date: Date()))",
            "DTSTART:\(format(date: start))"
        ])

        if let end = end {
            lines.append("DTEND:\(format(date: end))")
        }

        lines.append("SUMMARY:\(summary)")

        if let location = location {
            lines.append("LOCATION:\(location)")
        }

        lines.append("DESCRIPTION:Termin wurde abgesagt")

        if let attendee = attendee {
            lines.append("ORGANIZER;CN=\(organizerName):mailto:\(organizerEmail)")
            lines.append("ATTENDEE;CN=\(attendee);ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;RSVP=FALSE:mailto:\(attendee)")
        }

        lines.append(contentsOf: [
            "END:VEVENT",
            "END:VCALENDAR"
        ])

        return lines.joined(separator: "\r\n")
    }
    
    // MARK: - Mapping & Date

    static func mapSessionToIcsEvent(_ session: inout TreatmentSessions, attendee: String?) -> IcsEventData {
        let start = combine(date: session.date, time: session.startTime)
        let end = combine(date: session.date, time: session.endTime)
        if session.icsUid == nil {
            session.icsUid = UUID().uuidString
            session.icsSequence = 0
        }
        
        let sequence = session.icsSequence ?? 0
        
        let location = [
            session.address.street,
            "\(session.address.postalCode) \(session.address.city)",
            session.address.country
        ].joined(separator: ", ")

        return IcsEventData(
            uid: session.icsUid!,
            start: start,
            end: end,
            summary: AppGlobals.shared.practiceInfo.name,
            description: session.title,
            location: location,
            attendeeEmails: attendee != nil ? [attendee!] : nil,
            alertMinutesBefore: AppGlobals.shared.alertMinutesBefore,
            sequence: sequence
        )
    }

    private static func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    static func combine(date: Date, time: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return Calendar.current.date(from: components)!
    }
}
    
