//
//  CGRect.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.06.25.
//

import SwiftUI

extension CGRect {
    var isValid: Bool {
        !(origin.x.isNaN || origin.y.isNaN || size.width.isNaN || size.height.isNaN)
            && !self.isNull
            && !self.isEmpty
    }
}
