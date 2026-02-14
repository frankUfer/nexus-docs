//
//  YTracker.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 24.06.25.
//

import SwiftUI

struct YTracker {
    var currentY: CGFloat
    
    mutating func nextRect(x: CGFloat, width: CGFloat, height: CGFloat, spacing: CGFloat = 10) -> CGRect {
        let rect = CGRect(x: x, y: currentY, width: width, height: height)
        currentY -= (height + spacing)
        return rect
    }
}
