//
//  TimeSeriesData.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

/// Represents a time series of measured data points, such as for medical or scientific tracking.
struct TimeSeriesData: Identifiable, Codable, Hashable {
    /// Unique identifier for the time series.
    var id: UUID // = UUID()

    /// Title or description of the data series (e.g., "ROM Knee Joint").
    var title: String

    /// Unit of measurement for the data values (e.g., "°", "kg", "s").
    var unit: String

    /// Array of data points, each with a timestamp and value.
    var values: [DataPoint]
    
    init(id: UUID = UUID(), title: String, unit: String, values: [DataPoint] = []) {
           self.id = id
           self.title = title
           self.unit = unit
           self.values = values
       }
}

/// Represents a single data point in a time series, with a timestamp and a numeric value.
struct DataPoint: Identifiable, Codable, Hashable {
    /// Unique identifier for the data point.
    var id: UUID = UUID()

    /// The date and time when the measurement was taken.
    var timestamp: Date

    /// The measured value.
    var value: Double
}

