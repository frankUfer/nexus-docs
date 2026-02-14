//
//  DoubleOrBool.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

extension DoubleOrBool {
    var doubleValue: Double? {
        if case let .double(value) = self { return value }
        return nil
    }
}
