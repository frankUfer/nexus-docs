//
//  InvoiceNumberManager.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 21.06.25.
//

import Foundation

struct NumberState: Codable {
    var currentYear: Int
    var currentMonth: Int
    var counter: Int
}

struct NumberManager {
    private var state: NumberState
    private let fileURL: URL
    private let prefix: String

    init(fileName: String, prefix: String = "", startDate: Date = Date()) {
        self.prefix = prefix

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dirURL = documentsURL
            .appendingPathComponent("resources")
            .appendingPathComponent("parameter")
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        fileURL = dirURL.appendingPathComponent(fileName)

        if let data = try? Data(contentsOf: fileURL),
           let loadedState = try? JSONDecoder().decode(NumberState.self, from: data) {
            state = loadedState
        } else {
            let calendar = Calendar.current
            state = NumberState(
                currentYear: calendar.component(.year, from: startDate),
                currentMonth: calendar.component(.month, from: startDate),
                counter: 0
            )
        }
    }

    mutating func nextNumber(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        if year != state.currentYear || month != state.currentMonth {
            state.currentYear = year
            state.currentMonth = month
            state.counter = 0
        }

        state.counter += 1
        saveState()

        let yearStr = String(format: "%04d", state.currentYear)
        let monthStr = String(format: "%02d", state.currentMonth)
        let counterStr = String(format: "%04d", state.counter)

        return "\(prefix)\(yearStr)\(monthStr)\(counterStr)"
    }

    private func saveState() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
        }
    }
}
