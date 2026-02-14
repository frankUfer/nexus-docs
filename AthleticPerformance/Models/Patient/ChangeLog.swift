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
        let therapistId: Int?
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
