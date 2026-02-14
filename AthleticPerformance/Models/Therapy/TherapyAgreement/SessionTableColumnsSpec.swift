//
//  SessionTableColumnsSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import SwiftUI

struct SessionTableTableColumnSpec {
    let key: String
    let title: String
    let width: CGFloat
    let alignment: NSTextAlignment
    let fontName: String
    let fontSize: CGFloat
    let valueBuilder: (TreatmentSessions, Int) -> TableCellContent
}

struct SessionTableSpec {
    let columns: [SessionTableTableColumnSpec]
}

let defaultSessionTableSpec = SessionTableSpec(
    columns: [

        SessionTableTableColumnSpec(
            key: "dates",
            title: NSLocalizedString("date", comment: "Date"),
            width: 100,
            alignment: .left,
            fontName: "HelveticaNeue",
            fontSize: 12,
            valueBuilder: { item, _ in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "de_DE")
                formatter.dateFormat = "E dd.MM.yy"
                let dateStr = formatter.string(from: item.date)
                return TableCellContent(text: dateStr)
            }
        ),
        SessionTableTableColumnSpec(
            key: "timePeriod",
            title: NSLocalizedString("timePeriod", comment: "Time period"),
            width: 90,
            alignment: .left,
            fontName: "HelveticaNeue",
            fontSize: 12,
            valueBuilder: { item, _ in
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short

                let startStr = formatter.string(from: item.startTime)
                let endStr = formatter.string(from: item.endTime)

                return TableCellContent(
                    text: "\(startStr) - \(endStr)",
                    isBold: false
                )
            }
        ),
        SessionTableTableColumnSpec(
            key: "location",
            title: NSLocalizedString("location", comment: "Location"),
            width: 275,
            alignment: .left,
            fontName: "HelveticaNeue",
            fontSize: 12,
            valueBuilder: { item, _ in
                let street = StreetAbbreviator.abbreviate(item.address.street)
                let city = CityAbbreviator.abbreviate(item.address.city)
                
                return TableCellContent(
                    text: "\(street) - \(city)",
                    isBold: false)
            }
        )
    ]
)
