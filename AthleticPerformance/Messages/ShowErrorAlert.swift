//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 19.03.25.
//

import UIKit

func showErrorAlert(errorMessage: String) {
    DispatchQueue.main.async {
        let localizedTitle = NSLocalizedString("errorTitle", comment: "Title for error alert")
        let localizedOK = NSLocalizedString("okButton", comment: "OK button title")

        // aktive Szene + Key-Window holen
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            let root = window.rootViewController
        else { return }

        // ganz oben liegenden Presenter finden
        let presenter: UIViewController = {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            return top
        }()

        let alert = UIAlertController(title: localizedTitle, message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localizedOK, style: .default, handler: nil))
        presenter.present(alert, animated: true)
    }
}

