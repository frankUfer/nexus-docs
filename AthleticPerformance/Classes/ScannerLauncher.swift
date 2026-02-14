//
//  ScannerLauncher.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 25.04.25.
//

import SwiftUI
import UIKit
import MediaInputKit

public final class ScannerLauncher {
    public static func presentScanner(from presentingVC: UIViewController,
                                      onCapture: @escaping (Result<ScanOutput, Error>) -> Void,
                                      onCancel: (() -> Void)? = nil) {
        
        // VisionScannerView als SwiftUI View, eingebettet in ein UIKit View-Controller
        let scannerVC = UIHostingController(rootView: VisionScannerView(mode: .image) { result in
            switch result {
            case .success(.image(let image)):
                onCapture(.success(.image(image)))
                
            case .success(.pdf(let data)):
                onCapture(.success(.pdf(data)))
                
            case .failure(let error):
                onCapture(.failure(error))
            }
        })
        
        // Präsentation des Scanners
        presentingVC.present(scannerVC, animated: true, completion: nil)
    }
}
