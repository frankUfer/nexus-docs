//
//  Array.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.04.25.
//

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
