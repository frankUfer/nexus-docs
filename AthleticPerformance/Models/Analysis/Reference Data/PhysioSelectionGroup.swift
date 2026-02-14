//
//  PhysioSelectionGroup.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//


struct PhysioSelectionGroup: Codable, Hashable {
    var selectedBodyRegions: [BodyRegionSelectionGroup] = []
    var selectedFasciaRegions: [FasciaRegionSelectionGroup] = []
    var selectedMyofascialChains: [MyofascialChain] = []
    var selectedNeurologicalAreas: [NeurologicalArea] = []
    var selectedFunctionalUnits: [FunctionalUnit] = []
}

struct BodyRegionSelectionGroup: Codable, Hashable {
    var region: BodyRegionGroup
    var selectedParts: [BodyPart]
}

struct FasciaRegionSelectionGroup: Codable, Hashable {
    var region: FasciaRegion
    var selectedFasciae: [Fascia]
}

struct PhysioSelection: Codable, Hashable {
    var selectedMyofascialChains: [MyofascialChain] = []
    var selectedNeurologicalAreas: [NeurologicalArea] = []
    var selectedFunctionalUnits: [FunctionalUnit] = []
}
