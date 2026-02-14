//
//  GeocodingService.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 04.06.25.
//

import Foundation
import MapKit

//final class GeocodingService {
//    static let shared = GeocodingService()
//    private init() {}
//
//    /// Ergänzt eine Adresse um Koordinaten, falls nötig.
//    func geocodeIfNeeded(_ address: Address) async -> Address {
//        guard !address.hasCoordinates else { return address }
//
//        let query = address.fullDescription
//        let request = MKLocalSearch.Request()
//        request.naturalLanguageQuery = query
//
//        do {
//            let response = try await MKLocalSearch(request: request).start()
//            if let coordinate = response.mapItems.first?.placemark.coordinate {
//                var updated = address
//                updated.latitude = coordinate.latitude
//                updated.longitude = coordinate.longitude
//                return updated
//            }
//        } catch {
//            let message = "\(String(format: NSLocalizedString("errorGeocoding", comment: "Geocoding failed for"))) \(query): \(error.localizedDescription)"
//            showErrorAlert(errorMessage: message)
//        }
//
//        return address // ungeändert zurückgeben
//    }
//}

final class GeocodingService {
    static let shared = GeocodingService()
    private init() {}

    // NEW: simpler Memory-Cache
    private var cache: [String: Address] = [:]

    func geocodeIfNeeded(_ address: Address) async -> Address {
        // 1. Schon Koordinaten? Fertig.
        if address.hasCoordinates {
            return address
        }

        // 2. Schon mal in diesem Lauf geokodiert?
        let key = address.fullDescription
        if let cached = cache[key] {
            return cached
        }

        // 3. Erst jetzt wirklich Apple-Search
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = key

        do {
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                var updated = address
                updated.latitude = coordinate.latitude
                updated.longitude = coordinate.longitude
                cache[key] = updated       // <- merken!
                return updated
            }
        } catch {
            let message = "\(String(format: NSLocalizedString("errorGeocoding", comment: "Geocoding failed for"))) \(key): \(error.localizedDescription)"
            showErrorAlert(errorMessage: message)
        }

        // 4. Fallback: ungeändert zurück
        return address
    }
}
