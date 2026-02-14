//
//  isDuplicate.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.04.25.
//

func isDuplicate(name: String, in list: [NamedEntity]) -> Bool {
    let normalized = name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    return list.contains { existing in
        let existingNorm = existing.name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        return existingNorm == normalized
    }
}
