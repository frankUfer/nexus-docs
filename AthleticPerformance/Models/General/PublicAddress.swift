//
//  PublicAddress.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 03.07.25.
//

import Foundation

struct PublicAddressFile: Codable {
    var version: Int
    var items: [PublicAddress]
}

struct PublicAddress: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String      // Kategorie: „Fitness-Center“, „Sportplatz“ usw.
    var name: String       // Klartext-Name: z. B. „McFit Berlin Mitte“
    var address: Address   // Deine bestehende Address-Struktur
}
