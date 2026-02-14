//
//  AddressMapView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.04.25.
//

import SwiftUI
import MapKit
import CoreLocation

struct AddressMapView: View {
    var addressString: String

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Button {
            openInMaps()
        } label: {
            Group {
                if let coordinate = coordinate,
                   CLLocationCoordinate2DIsValid(coordinate),
                   coordinate.latitude.isFinite,
                   coordinate.longitude.isFinite {

                    Map(position: $cameraPosition) {
                        Marker(addressString, coordinate: coordinate)
                    }
                    .frame(height: 150)
                    .cornerRadius(12)
                    .onAppear {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }

                } else {
                    ProgressView()
                        .frame(height: 150)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            geocodeAddress()
        }
    }

    private func geocodeAddress() {
        // Schutz gegen leere oder sinnlose Eingaben
        let trimmed = addressString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(trimmed) { placemarks, error in
            if let location = placemarks?.first?.location {
                let c = location.coordinate
                if CLLocationCoordinate2DIsValid(c),
                   c.latitude.isFinite,
                   c.longitude.isFinite {
                    self.coordinate = c
                } else {
                      let message = "\(String(format: NSLocalizedString("errorCoodinateNotValid", comment: "Receiving invalid coordinates"))): \(c)"
                    showErrorAlert(errorMessage: message)
                }
            } else {
                let message = "\(String(format: NSLocalizedString("errorGeocoding", comment: "Geocoding failed for"))) \(trimmed): \(error?.localizedDescription ?? "")"
                showErrorAlert(errorMessage: message)
            }
        }
    }

    private func openInMaps() {
        let trimmed = addressString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
