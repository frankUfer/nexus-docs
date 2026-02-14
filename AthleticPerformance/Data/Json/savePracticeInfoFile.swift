//
//  saveJSON.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import Foundation

func savePracticeInfoFile(_ file: PracticeInfoFile, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let data = try encoder.encode(file)

    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    try data.write(to: url, options: .atomic)
}
