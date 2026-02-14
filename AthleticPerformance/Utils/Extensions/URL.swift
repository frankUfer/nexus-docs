//
//  URL.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 05.06.25.
//

import Foundation

struct ShareableFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
