//
//  PhysioReferenceData.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 11.04.25.
//

import Foundation

struct PhysioReferenceDataFile: Codable {
    var version: Int
    var items: [PhysioReferenceData]
}

/// Container for structured physiological reference data used in therapy.
struct PhysioReferenceData: Codable {
    /// List of body region groups and their parts.
    let bodyRegions: [BodyRegionGroup]

    /// List of fascia regions and their components.
    let fasciaRegions: [FasciaRegion]

    /// List of myofascial chains.
    let myofascialChains: [MyofascialChain]

    /// List of neurological areas.
    let neurologicalAreas: [NeurologicalArea]

    /// List of functional anatomical units.
    let functionalUnits: [FunctionalUnit]
}

/// Represents a group of anatomical body regions with localized names and sub-parts.
struct BodyRegionGroup: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German region name.
    var id: String { region_de }

    /// Region group name in German (e.g., "Obere Extremität").
    let region_de: String

    /// Region group name in English (e.g., "Upper Extremity").
    let region_en: String

    /// List of body parts belonging to this region group.
    let parts: [BodyPart]
}

/// Represents a localized anatomical body part within a region group.
struct BodyPart: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German part name.
    var id: String { de }

    /// Body part name in German (e.g., "Schulter").
    let de: String

    /// Body part name in English (e.g., "Shoulder").
    let en: String
}

/// Represents a group of fasciae (connective tissues) with localized names.
struct FasciaRegion: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German fascia region name.
    var id: String { region_de }

    /// Fascia region name in German (e.g., "Thorakolumbale Faszie").
    let region_de: String

    /// Fascia region name in English (e.g., "Thoracolumbar Fascia").
    let region_en: String

    /// List of specific fasciae in this region.
    let fasciae: [Fascia]
}

/// Represents a localized fascia (connective tissue) within a region.
struct Fascia: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German fascia name.
    var id: String { de }

    /// Fascia name in German (e.g., "Fascia thoracolumbalis").
    let de: String

    /// Fascia name in English (e.g., "Thoracolumbar fascia").
    let en: String
}

/// Represents a myofascial chain with localized names.
struct MyofascialChain: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German chain name.
    var id: String { de }

    /// Chain name in German (e.g., "Laterale Linie").
    let de: String

    /// Chain name in English (e.g., "Lateral Line").
    let en: String
}

/// Represents a neurological area with localized names.
struct NeurologicalArea: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German area name.
    var id: String { de }

    /// Area name in German (e.g., "Brachialplexus").
    let de: String

    /// Area name in English (e.g., "Brachial Plexus").
    let en: String
}

/// Represents a functional anatomical unit with localized names.
struct FunctionalUnit: Codable, Identifiable, Hashable {
    /// Unique identifier derived from the German unit name.
    var id: String { de }

    /// Unit name in German (e.g., "Sprunggelenk").
    let de: String

    /// Unit name in English (e.g., "Ankle Joint").
    let en: String
}

extension PhysioReferenceData {
    /// An empty instance used as a default/placeholder value.
    static let empty = PhysioReferenceData(
        bodyRegions: [],
        fasciaRegions: [],
        myofascialChains: [],
        neurologicalAreas: [],
        functionalUnits: []
    )
}

extension BodyRegionSelectionGroup: Identifiable {
    var id: String { region.id }
}

extension BodyRegionGroup {
    func localized(locale: Locale = .current) -> String {
        let lang = locale.language.languageCode?.identifier ?? "en"
        return lang == "de" ? region_de : region_en
    }
}

extension BodyPart {
    func localized(locale: Locale = .current) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return de
        default: return en
        }
    }
}
