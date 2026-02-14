//
//  AvailabilityData.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 14.04.25.
//

/// A dictionary mapping therapist IDs to their list of availability entries.
/// - Key: `Int` — The unique identifier of the therapist.
/// - Value: `[AvailabilityEntry]` — An array of availability entries for that therapist.
typealias AvailabilityData = [Int: [AvailabilityEntry]]

