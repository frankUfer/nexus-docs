//
//  KnowledgeBase.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 04.11.25.
//

import Foundation

// MARK: - Knowledge Base (Top-Level)

public struct KnowledgeBase: Codable {
    public var globalAliases: GlobalAliases
    public var praxisProfiles: [PraxisProfile]
    public var canonicalValues: CanonicalValues
    public var postalCodes: PostalCodes
    public var rulesMeta: RulesMeta

    // NEU: Globales Lexikon (Stopwörter, medizinische Tokens, typische Mengen)
    public var globalLexicon: GlobalLexicon

    public init(globalAliases: GlobalAliases = .init(),
                praxisProfiles: [PraxisProfile] = [],
                canonicalValues: CanonicalValues = .init(),
                postalCodes: PostalCodes = .init(),
                rulesMeta: RulesMeta = .init(),
                globalLexicon: GlobalLexicon = .init()) {
        self.globalAliases = globalAliases
        self.praxisProfiles = praxisProfiles
        self.canonicalValues = canonicalValues
        self.postalCodes = postalCodes
        self.rulesMeta = rulesMeta
        self.globalLexicon = globalLexicon
    }
}

// MARK: - Global Aliases (kanonischer Begriff -> Varianten)

/// Alias-Liste für einen kanonischen Begriff (Bezeichnungen bitte in Kleinbuchstaben normalisiert speichern)
public typealias AliasList = [String]

/// Map: kanonisch -> Liste von Schreibvarianten
public typealias AliasMap = [String: AliasList]

public struct GlobalAliases: Codable {
    public var diagnoses: AliasMap
    public var remedies: AliasMap
    public var specialties: AliasMap
    public var other: AliasMap

    public init(diagnoses: AliasMap = [:],
                remedies: AliasMap = [:],
                specialties: AliasMap = [:],
                other: AliasMap = [:]) {
        self.diagnoses = diagnoses
        self.remedies = remedies
        self.specialties = specialties
        self.other = other
    }
}

// MARK: - Global Lexicon (Stopwörter, Tokens, Mengen) — NEU

public struct GlobalLexicon: Codable {
    /// Globale Stopwörter / Organisationswörter (z. B. "gmbh", "mvz", "zentrum", "klinik", "praxis")
    public var noiseWords: [String]
    /// Einfache medizinische Tokens (für Titel-Boost, optional)
    public var medicalTokens: [String]
    /// Typische Mengenangaben für Heilmittel (z. B. 6, 10, 12, 18)
    public var typicalQuantities: [Int]

    public init(noiseWords: [String] = [],
                medicalTokens: [String] = [],
                typicalQuantities: [Int] = []) {
        self.noiseWords = noiseWords
        self.medicalTokens = medicalTokens
        self.typicalQuantities = typicalQuantities
    }
}

// MARK: - Canonical Values (aktuelle Kanonformen)

public enum CanonicalSource: String, Codable {
    case system, user, importFile
}

/// Ein einzelner Kanonwert (aktive Schreibweise). Historisierung kannst du separat führen.
public struct CanonicalEntry: Codable, Hashable {
    public var id: UUID
    public var canonical: String
    /// Optional: fachliche/extern vergebene ID (z. B. Service-UUID)
    public var externalId: String?          // NEU
    public var lastModified: Date
    public var source: CanonicalSource
    /// Optional: knapper Änderungsgrund (z. B. "user-confirmation", "python-pretrain")
    public var lastChangeReason: String?     // NEU

    public init(id: UUID = UUID(),
                canonical: String,
                externalId: String? = nil,
                lastModified: Date = Date(),
                source: CanonicalSource = .user,
                lastChangeReason: String? = nil) {
        self.id = id
        self.canonical = canonical
        self.externalId = externalId
        self.lastModified = lastModified
        self.source = source
        self.lastChangeReason = lastChangeReason
    }
}

public struct CanonicalValues: Codable {
    public var remedies: [CanonicalEntry]
    public var specialties: [CanonicalEntry]
    public var institutions: [CanonicalEntry]   // Praxis-/Institutionsnamen
    public var misc: [CanonicalEntry]           // sonstige Kanonika (falls benötigt)
    /// NEU: Kanon für Diagnosen (damit Korrekturen "ersetzen" können)
    public var diagnoses: [CanonicalEntry]

    public init(remedies: [CanonicalEntry] = [],
                specialties: [CanonicalEntry] = [],
                institutions: [CanonicalEntry] = [],
                misc: [CanonicalEntry] = [],
                diagnoses: [CanonicalEntry] = []) {
        self.remedies = remedies
        self.specialties = specialties
        self.institutions = institutions
        self.misc = misc
        self.diagnoses = diagnoses
    }
}

// MARK: - Praxis Profiles (absender-/praxisbezogene Varianten & Präferenzen)

public struct PraxisAliases: Codable, Hashable {
    /// Praxis-spezifische Aliaslisten (überschreiben/ergänzen Global)
    public var remedies: AliasMap
    public var specialties: AliasMap
    public var diagnoses: AliasMap

    public init(remedies: AliasMap = [:],
                specialties: AliasMap = [:],
                diagnoses: AliasMap = [:]) {
        self.remedies = remedies
        self.specialties = specialties
        self.diagnoses = diagnoses
    }
}

public struct PraxisDateRules: Codable, Hashable {
    /// Tokens, nach denen Datums-Kandidaten bevorzugt werden (z. B. ["diagnose","diag","dg"])
    public var preferTokens: [String]
    /// Tokens, die Datums-Kandidaten abwerten (z. B. ["op","operation","operiert"])
    public var avoidTokens: [String]
    /// Ob bei Unentschieden das jüngste Datum bevorzugt werden soll
    public var preferMostRecent: Bool

    public init(preferTokens: [String] = [],
                avoidTokens: [String] = [],
                preferMostRecent: Bool = true) {
        self.preferTokens = preferTokens
        self.avoidTokens = avoidTokens
        self.preferMostRecent = preferMostRecent
    }
}

/// Freiform-Gewichtsanpassungen auf Praxis-Ebene (Key-Pfade, z. B. "diagnosisDate.keywords.op": -0.2)
public typealias WeightOffsets = [String: Double]

public struct PraxisProfile: Codable, Identifiable, Hashable {
    public var id: String              // stabiler Key, z. B. Hash aus Name + Telefonstamm
    public var displayName: String
    public var phoneStem: String?      // z. B. "0409886"
    public var domain: String?         // z. B. "praxis-maier.de"
    public var aliases: PraxisAliases
    public var specialtyOverrides: [String]   // bevorzugte Fachrichtung(en) für diese Praxis
    public var dateRules: PraxisDateRules
    public var weightOffsets: WeightOffsets
    public var noiseWords: [String]    // z. B. ["gmbh","mvz","zentrum"]

    // Optional persistierbar: Name-Tokens zur leichteren Wiedererkennung (kannst du auch nur zur Laufzeit bilden)
    public var nameTokens: [String]?   // NEU (optional)

    public var lastUpdated: Date

    public init(id: String,
                displayName: String,
                phoneStem: String? = nil,
                domain: String? = nil,
                aliases: PraxisAliases = .init(),
                specialtyOverrides: [String] = [],
                dateRules: PraxisDateRules = .init(),
                weightOffsets: WeightOffsets = [:],
                noiseWords: [String] = [],
                nameTokens: [String]? = nil,
                lastUpdated: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.phoneStem = phoneStem
        self.domain = domain
        self.aliases = aliases
        self.specialtyOverrides = specialtyOverrides
        self.dateRules = dateRules
        self.weightOffsets = weightOffsets
        self.noiseWords = noiseWords
        self.nameTokens = nameTokens
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Postal Codes (PLZ ↔ Ort)

public struct PostalCodes: Codable, Hashable {
    /// Rohdaten aus der CSV: Liste (PLZ, Stadt)
    public var entries: [PostalcodeCity]

    /// Laufzeit-Index: "10115" -> ["Berlin", ...] (nicht codiert, wird beim Laden gebaut)
    public var indexByPLZ: [String: [String]] = [:]

    public init(entries: [PostalcodeCity] = []) {
        self.entries = entries
        self.rebuildIndex()
    }

    /// Baue/aktualisiere den Index. Du rufst das auf, wenn `entries` ersetzt werden (z. B. nach CSV-Import).
    public mutating func rebuildIndex() {
        // Gruppieren nach PLZ und Städte de-duplizieren
        var tmp: [String: Set<String>] = [:]
        for e in entries {
            tmp[e.postalCode, default: []].insert(e.city)
        }
        self.indexByPLZ = tmp.mapValues { Array($0).sorted() }
    }

    /// Alle Städte zu einer (rohen) PLZ – inkl. Normalisierung (führende Nullen etc.)
    public func cities(forPostalCode raw: String) -> [String] {
        let norm = PostalcodeCity(postalCode: raw, city: "").postalCode
        return indexByPLZ[norm] ?? []
    }

    /// Prüft Kohärenz: passt (PLZ, Ort) zusammen?
    public func matches(postalCode raw: String, city rawCity: String) -> Bool {
        let normCity = rawCity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cities(forPostalCode: raw).map { $0.lowercased() }.contains(normCity)
    }

    // Nur `entries` serialisieren – den Index bewusst auslassen
    private enum CodingKeys: String, CodingKey { case entries }
}

// MARK: - Rules Meta (Gewichtstabellen + Versionierung)

public struct RulesVersionInfo: Codable {
    public var version: String        // z. B. "1.0.0"
    public var lastEdited: Date

    public init(version: String = "1.0.0",
                lastEdited: Date = Date()) {
        self.version = version
        self.lastEdited = lastEdited
    }
}

// NEU: Globale Schlüsselwort-Listen für Datum (Listen ≠ Gewichte)
public struct DateKeywordLists: Codable {
    public var prefer: [String]   // z. B. ["diagnose","diag","dg"]
    public var avoid: [String]    // z. B. ["op","operation","operiert"]

    public init(prefer: [String] = [], avoid: [String] = []) {
        self.prefer = prefer
        self.avoid = avoid
    }
}

// NEU: Harte Guards für Datumsauswahl
public struct DateGuards: Codable {
    public var allowFuture: Bool          // default: false
    public var futureSlackDays: Int       // z. B. 7

    public init(allowFuture: Bool = false, futureSlackDays: Int = 7) {
        self.allowFuture = allowFuture
        self.futureSlackDays = futureSlackDays
    }
}

// NEU: Policy für Praxis-Offsets (Leitplanken)
public struct WeightPolicy: Codable {
    public var offsetCap: Double          // z. B. 0.2
    public var allowedOffsetKeys: [String]// erlaubte Schlüssel für Offsets

    public init(offsetCap: Double = 0.2, allowedOffsetKeys: [String] = []) {
        self.offsetCap = offsetCap
        self.allowedOffsetKeys = allowedOffsetKeys
    }
}

// Feinere, typisierte Gewichte (lesbarer als eine große String->Double-Map)
public struct DiagnosisDateWeights: Codable {
    public var keywords: [String: Double]   // {"diagnose": +0.6, "op": -0.6, ...}
    public var position: [String: Double]   // {"inBlock": +0.1, "mostRecent": +0.1}
    public var fallback: String             // z. B. "mostRecentIfNone"

    public init(keywords: [String: Double] = [:],
                position: [String: Double] = [:],
                fallback: String = "mostRecentIfNone") {
        self.keywords = keywords
        self.position = position
        self.fallback = fallback
    }
}

public struct RemediesWeights: Codable {
    public var exactMatch: Double
    public var globalAlias: Double
    public var praxisAlias: Double
    public var typicalQuantity: Double

    public init(exactMatch: Double = 0.7,
                globalAlias: Double = 0.3,
                praxisAlias: Double = 0.3,
                typicalQuantity: Double = 0.1) {
        self.exactMatch = exactMatch
        self.globalAlias = globalAlias
        self.praxisAlias = praxisAlias
        self.typicalQuantity = typicalQuantity
    }
}

public struct AddressWeights: Codable {
    public var plzValid: Double
    public var plzOrtMatch: Double
    public var streetPattern: Double

    public init(plzValid: Double = 0.9,
                plzOrtMatch: Double = 0.5,
                streetPattern: Double = 0.6) {
        self.plzValid = plzValid
        self.plzOrtMatch = plzOrtMatch
        self.streetPattern = streetPattern
    }
}

/// Sammelpunkt aller Gewichtungen
public struct RulesWeights: Codable {
    public var diagnosisDate: DiagnosisDateWeights
    public var remedies: RemediesWeights
    public var address: AddressWeights

    public init(diagnosisDate: DiagnosisDateWeights = .init(),
                remedies: RemediesWeights = .init(),
                address: AddressWeights = .init()) {
        self.diagnosisDate = diagnosisDate
        self.remedies = remedies
        self.address = address
    }
}

public struct RulesMeta: Codable {
    public var weights: RulesWeights
    public var versionInfo: RulesVersionInfo

    // NEU: globale Datum-Keyword-Listen (separat von Gewichten)
    public var dateKeywords: DateKeywordLists
    // NEU: harte Guards für Datumsauswahl
    public var dateGuards: DateGuards
    // NEU: Policy für praxisbezogene WeightOffsets (Deckel + erlaubte Keys)
    public var weightPolicy: WeightPolicy

    public init(weights: RulesWeights = .init(),
                versionInfo: RulesVersionInfo = .init(),
                dateKeywords: DateKeywordLists = .init(),
                dateGuards: DateGuards = .init(),
                weightPolicy: WeightPolicy = .init()) {
        self.weights = weights
        self.versionInfo = versionInfo
        self.dateKeywords = dateKeywords
        self.dateGuards = dateGuards
        self.weightPolicy = weightPolicy
    }
}
