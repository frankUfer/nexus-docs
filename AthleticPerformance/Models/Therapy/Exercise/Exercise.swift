//
//  Exercise.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    var id: UUID // = UUID()
    var title: String                     // z. B. "Kniebeugen mit Ball"
    var description: String               // Anleitung / Textinfo
    var assignedDate: Date                // Wann wurde sie verordnet?
    var startDate: Date?                  // Ab wann durchführen
    var endDate: Date?                    // Bis wann durchführen (optional)
    var mediaFiles: [MediaFile] = []     // Bilder, Videos, Audios etc.
    var repetitions: Int?                // z. B. 10 Wiederholungen
    var sets: Int?                       // z. B. 3 Sätze
    var holdDuration: TimeInterval?      // Haltezeit bei statischen Übungen in Sekunden
    var restDuration: TimeInterval?      // Pause zwischen den Sätzen in Sekunden
    var tags: [String]?                  // z. B. ["Koordination", "Bein", "Reha"]
    var therapistId: UUID

    enum CodingKeys: String, CodingKey {
        case id, title, description, assignedDate, startDate, endDate,
             mediaFiles, repetitions, sets, holdDuration, restDuration,
             tags, therapistId
    }

    init(
           id: UUID = UUID(),
           title: String,
           description: String,
           assignedDate: Date,
           startDate: Date? = nil,
           endDate: Date? = nil,
           mediaFiles: [MediaFile] = [],
           repetitions: Int? = nil,
           sets: Int? = nil,
           holdDuration: TimeInterval? = nil,
           restDuration: TimeInterval? = nil,
           tags: [String]? = nil,
           therapistId: UUID
       ) {
           self.id = id
           self.title = title
           self.description = description
           self.assignedDate = assignedDate
           self.startDate = startDate
           self.endDate = endDate
           self.mediaFiles = mediaFiles
           self.repetitions = repetitions
           self.sets = sets
           self.holdDuration = holdDuration
           self.restDuration = restDuration
           self.tags = tags
           self.therapistId = therapistId
       }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        assignedDate = try container.decode(Date.self, forKey: .assignedDate)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        mediaFiles = try container.decodeIfPresent([MediaFile].self, forKey: .mediaFiles) ?? []
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions)
        sets = try container.decodeIfPresent(Int.self, forKey: .sets)
        holdDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .holdDuration)
        restDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .restDuration)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        therapistId = try decodeTherapistId(from: container, forKey: .therapistId)
    }
}
