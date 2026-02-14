//
//  PainScale.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

struct PainLevels: Codable, Hashable, Identifiable {
    let value: Int
    var id: Int { value }

    init(_ value: Int) {
        self.value = min(max(value, 0), 10)
    }
}
