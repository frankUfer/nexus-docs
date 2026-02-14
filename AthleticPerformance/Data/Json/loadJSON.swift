//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

func loadJSON<T: Decodable>(from url: URL) -> T? {
  do {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(T.self, from: data)
  } catch {
    showErrorAlert(errorMessage: String(
      format: NSLocalizedString("errorLoadingFile", comment: "Error loading file %@: %@"),
      url.lastPathComponent,
      error.localizedDescription
    ))
    return nil
  }
}
