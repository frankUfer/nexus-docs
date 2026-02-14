//
//  TravelTimeService.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 04.06.25.
//

import Foundation
import MapKit

final class TravelTimeService {
    static let shared = TravelTimeService()
    
    private init() {}

    /// Schätzt die Reisezeit zwischen zwei Adressen per Auto.
    /// - Parameters:
    ///   - origin: Startadresse
    ///   - destination: Zieladresse
    /// - Returns: Geschätzte Reisezeit in Sekunden, inkl. ggf. Puffer
    func estimateTravelTime(from origin: Address, to destination: Address) async -> TimeInterval {
        let originCoordinate = CLLocationCoordinate2D(
            latitude: origin.latitude ?? 0,
            longitude: origin.longitude ?? 0
        )
        let destinationCoordinate = CLLocationCoordinate2D(
            latitude: destination.latitude ?? 0,
            longitude: destination.longitude ?? 0
        )

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: originCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .automobile

        do {
            let response = try await MKDirections(request: request).calculate()
            let baseTime = response.routes.first?.expectedTravelTime ?? defaultFallbackTime()

            return applyBufferIfNeeded(to: baseTime, origin: origin)
        } catch {
            return applyBufferIfNeeded(to: defaultFallbackTime(), origin: origin)
        }
    }

    /// Standardwert bei Fehlern oder fehlender Route (20 Minuten)
    private func defaultFallbackTime() -> TimeInterval {
        return 20 * 60
    }

    /// Pufferzeit (aus AppGlobals) wird nur hinzugefügt, wenn nicht von der Praxis gestartet wird
    private func applyBufferIfNeeded(to time: TimeInterval, origin: Address) -> TimeInterval {
        if !origin.isSameLocation(as: AppGlobals.shared.practiceInfo.startAddress) {
            let buffer = TimeInterval(AppGlobals.shared.travelBuffer * 60)
            return time + buffer
        } else {
            return time
        }
    }
}
