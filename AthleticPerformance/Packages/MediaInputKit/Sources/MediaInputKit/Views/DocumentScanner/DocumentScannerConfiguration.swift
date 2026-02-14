//
//  DocumentScannerConfiguration.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 25.04.25.
//

// DocumentScannerViewController.swift
// MediaInputKit

import UIKit

public struct DocumentScannerConfiguration: Sendable {
    public var maxPages: Int = 10
    public var autoCaptureEnabled: Bool = true
    public var showsCancelButton: Bool = true
    public var themeColor: UIColor = .systemBlue

    public static let `default` = DocumentScannerConfiguration()
    public init() {}
}
