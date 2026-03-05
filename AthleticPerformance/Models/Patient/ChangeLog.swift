//
//  ChangeLog.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 05.10.25.
//

import Foundation

struct ChangeLog: Codable {
    struct ChangeEntry: Codable {
        let path: String
        let oldValue: String
        let newValue: String
        let therapistId: UUID?

        init(path: String, oldValue: String, newValue: String, therapistId: UUID?) {
            self.path = path
            self.oldValue = oldValue
            self.newValue = newValue
            self.therapistId = therapistId
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            path = try c.decode(String.self, forKey: .path)
            oldValue = try c.decode(String.self, forKey: .oldValue)
            newValue = try c.decode(String.self, forKey: .newValue)
            therapistId = try decodeOptionalTherapistId(from: c, forKey: .therapistId)
        }
    }

    let changes: [ChangeEntry]
}

// MARK: - Formatters (UTC, stabil)

let fileStampFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyyMMdd-HH:mm:ss"   // ⇐ Dateiname: YYYYMMDD-HH:MM:SEC
    return df
}()
