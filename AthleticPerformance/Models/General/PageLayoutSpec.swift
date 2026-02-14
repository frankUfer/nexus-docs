//
//  InvoiceLayout.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import SwiftUI

struct PageLayoutSpec {
    let pageRect: CGRect
    let pageStart: CGFloat
    let pageEnd: CGFloat
    let marginTop: CGFloat
    let marginBottom: CGFloat
    let marginLeft: CGFloat
    let marginRight: CGFloat
    let logoRect: CGRect
    let textStartY: CGFloat
    let tableStartY: CGFloat
}

// Seitenlayout
let pageWidth: CGFloat = 595
let pageHeight: CGFloat = 842
let top: CGFloat = 28
let bottom: CGFloat = 56
let left: CGFloat = 70
let right: CGFloat = 56
let pageStartPosition: CGFloat = top + 100
let pageEndPosition: CGFloat = pageHeight - bottom - 100

let defaultLayout = PageLayoutSpec(
    pageRect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
    pageStart: pageStartPosition,
    pageEnd: pageEndPosition,
    marginTop: top,
    marginBottom: bottom,
    marginLeft: left,
    marginRight: right,
    logoRect: CGRect(x: pageWidth - right - 100, y: top, width: 100, height: 50),
    textStartY: top + 70,
    tableStartY: top + 300,
)

