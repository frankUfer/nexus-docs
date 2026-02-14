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
    var therapistId: Int                 // Wer hat sie angeordnet?
    
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
           therapistId: Int
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
}
