//
//  TravelTimeManager.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 04.06.25.
//

import Foundation

//final class TravelTimeManager {
//    private var travelTimeCache: [String: TimeInterval] = [:]

final class TravelTimeManager {
    static let shared = TravelTimeManager()

    private var travelTimeCache: [String: TimeInterval] = [:]

    func determineStartAddress(around candidate: Date, context: SessionPlanningContext, sessionsToday: [TreatmentSessions]) async -> Address {
        if let closest = sessionsToday.min(by: {
            abs($0.startTime.timeIntervalSince(candidate)) < abs($1.startTime.timeIntervalSince(candidate))
        }) {
            return await GeocodingService.shared.geocodeIfNeeded(closest.address)
        } else {
            return context.updatedPracticeAddress
        }
    }

    func calculateConfirmedTravelTime(
        from: Address,
        to: Address,
        validator: TravelTimeValidator,
        requireConfirmation: Bool = true
    ) async -> TimeInterval? {
        // Früh raus, wenn keine Reise nötig ist
        if from.isSameLocation(as: to)
            || from.isSameLocation(as: AppGlobals.shared.practiceInfo.startAddress)
            || to.isSameLocation(as: AppGlobals.shared.practiceInfo.startAddress) {
            return 0
        }

        // Cache-Key auf Basis von Adress-Hashes
        let key = "\(from.cacheKey)->\(to.cacheKey)"
        if let cached = travelTimeCache[key] {
            return cached
        }

        // Reisezeit schätzen
        let estimated = await TravelTimeService.shared.estimateTravelTime(from: from, to: to)
        let estimatedMinutes = Int(estimated / 60)
        
        let confirmed: Int?
        if requireConfirmation {
            confirmed = await validator.confirmTravelTime(
                estimatedMinutes: estimatedMinutes,
                origin: from,
                destination: to
            )
        } else {
            confirmed = estimatedMinutes
        }

        guard let finalMinutes = confirmed else {
            return nil // Abbruch durch Nutzer
        }

        let confirmedInterval = TimeInterval(finalMinutes * 60)
        travelTimeCache[key] = confirmedInterval
        return confirmedInterval
    }
}
