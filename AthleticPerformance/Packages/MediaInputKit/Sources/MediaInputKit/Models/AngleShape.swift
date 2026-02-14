//
//  AngleShape.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//

import SwiftUI

public struct AngleShape: Identifiable {
    public var id: UUID // = UUID()

    public var origin: CGPoint
    public var point1: CGPoint
    public var point2: CGPoint
    public var color: Color
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        origin: CGPoint,
        point1: CGPoint,
        point2: CGPoint,
        color: Color = .blue.opacity(0.5),
        isSelected: Bool = false
    ) {
        self.id = id
        self.origin = origin
        self.point1 = point1
        self.point2 = point2
        self.color = color
        self.isSelected = isSelected
    }
}
