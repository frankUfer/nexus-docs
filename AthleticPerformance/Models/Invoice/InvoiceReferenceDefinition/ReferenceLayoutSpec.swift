//
//  ReferenceLayoutSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import SwiftUI

struct ReferenceLayoutSpec {
    let pageRect: CGRect
    let marginTop: CGFloat
    let marginBottom: CGFloat
    let marginLeft: CGFloat
    let marginRight: CGFloat
    let logoRect: CGRect
    let headerRect: CGFloat
    let tableStartY: CGFloat
}

let defaultReferenceLayout = ReferenceLayoutSpec(
    pageRect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
    marginTop: top,
    marginBottom: bottom,
    marginLeft: left,
    marginRight: right,
    logoRect: CGRect(x: pageWidth - right - 100, y: top, width: 100, height: 50),
    headerRect: top + 70,
    tableStartY: top,
)

