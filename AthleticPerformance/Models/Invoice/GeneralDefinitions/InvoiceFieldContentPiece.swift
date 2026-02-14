//
//  InvoiceFieldContentPiece.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

import UIKit

struct InvoiceFieldContentPiece {
    let text: String
    let isBold: Bool
    let isItalic: Bool
    let color: UIColor
}

struct InvoiceFieldBlockStyle {
    let fontName: String
    let fontSize: CGFloat
    let alignment: NSTextAlignment
    let lineSpacing: CGFloat
}

struct InvoiceFieldBlockSpec {
    let key: String
    let description: String
    let position: CGRect
    let style: InvoiceFieldBlockStyle
    let type: InvoiceFieldBlockType
    let valueBuilder: (Invoice) -> [InvoiceFieldPieceSpec]
}

struct InvoiceFieldPieceSpec {
    let label: InvoiceFieldContentPiece?
    let content: InvoiceFieldContentPiece
}
