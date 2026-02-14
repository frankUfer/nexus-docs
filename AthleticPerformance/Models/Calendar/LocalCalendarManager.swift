//
//  LocalCalendarManager.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.06.25.
//

import EventKit
import UIKit

struct LocalCalendarManager {
    private static let calendarName = AppGlobals.shared.calendarName
    private static let calendarIdentifierKey = "MyAppCalendarIdentifier"
    
    
    static func ensureCalendarExists() {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, error in
            guard granted, error == nil else { return }
            _ = getOrCreateCalendar(store: store)
        }
    }

    // MARK: - Entry Point

    static func createEvent(for session: TreatmentSessions,
                            position: Int? = nil,
                            total: Int? = nil,
                            completion: @escaping (String?) -> Void) {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, error in
            guard granted, error == nil else {
                completion(nil)
                return
            }

            guard let calendar = getOrCreateCalendar(store: store) else {
                completion(nil)
                return
            }

            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            
            let baseTitle = session.title
            if let pos = position, let tot = total, pos > 0, tot > 0 {
                event.title = "\(baseTitle)" // (\(pos)/\(tot))"
            } else {
                event.title = baseTitle
            }

            event.startDate = IcsGenerator.combine(date: session.date, time: session.startTime)
            event.endDate = IcsGenerator.combine(date: session.date, time: session.endTime)
            event.notes = "Therapie: \(session.title)"
            
            // 🗺️ Adresse in Location eintragen
            let addr = session.address
            event.location = "\(addr.street), \(addr.postalCode) \(addr.city)"

            if let uid = session.icsUid {
                event.url = URL(string: "ics:\(uid)")
            }

            do {
                try store.save(event, span: .thisEvent)
                completion(event.eventIdentifier)
            } catch {
                completion(nil)
            }
        }
    }

    static func deleteEvent(identifier: String?, uid: String?) {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, error in
            guard granted, error == nil else {
                return
            }

            DispatchQueue.main.async {
                var foundEvent: EKEvent?

                if let identifier = identifier, let event = store.event(withIdentifier: identifier) {
                    foundEvent = event
                } else if let uid = uid {
                    let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
                    let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
                    let predicate = store.predicateForEvents(withStart: oneYearAgo, end: oneYearFromNow, calendars: nil)
                    let events = store.events(matching: predicate)

                    foundEvent = events.first(where: { $0.url?.absoluteString == "ics:\(uid)" })
                }

                guard let event = foundEvent else {
                    return
                }

                do {
                    try store.remove(event, span: .thisEvent, commit: true)
                } catch {
                    // Ignoriere Fehler
                }
            }
        }
    }

    // MARK: - Calendar Management

    private static func getOrCreateCalendar(store: EKEventStore) -> EKCalendar? {
        // 1️⃣ Prüfe gespeicherten Identifier
        if let id = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let calendar = store.calendar(withIdentifier: id) {
            return calendar
        }

        // 2️⃣ Prüfe, ob bereits ein Kalender existiert (egal wo)
        let allCalendars = store.calendars(for: .event)
        if let existing = allCalendars.first(where: { $0.title == calendarName }) {
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: calendarIdentifierKey)
            return existing
        }

        // 3️⃣ Suche NUR iCloud-Source
        guard let icloudSource = store.sources.first(where: {
            $0.title == "iCloud" && $0.sourceType == .calDAV
        }) else {
            return nil
        }

        // 4️⃣ Neu anlegen im iCloud-Account
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarName
        calendar.source = icloudSource
        calendar.cgColor = UIColor.systemBlue.cgColor

        do {
            try store.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
            return calendar
        } catch {
            return nil
        }
    }
}
