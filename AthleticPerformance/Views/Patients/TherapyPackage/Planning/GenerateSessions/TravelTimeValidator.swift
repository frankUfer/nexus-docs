//
//  TravelTimeValidator.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 02.06.25.
//

// TravelTimeValidator.swift
protocol TravelTimeValidator {
    func confirmTravelTime(estimatedMinutes: Int, origin: Address, destination: Address) async -> Int?
}
