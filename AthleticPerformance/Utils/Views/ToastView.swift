//
//  ToastView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.05.25.
//

import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.error.opacity(0.85))
                .foregroundColor(.black)
                .cornerRadius(12)
                .shadow(radius: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

enum GlobalToast {
    static var toastWindow: UIWindow?

    static func show(_ message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            let toastView = ToastView(message: message)
            let hosting = UIHostingController(rootView: toastView)
            hosting.view.backgroundColor = .clear
            hosting.view.alpha = 0 // 👈 Start mit 0

            guard let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                return
            }

            let window = UIWindow(windowScene: windowScene)
            window.frame = UIScreen.main.bounds
            window.rootViewController = hosting
            window.windowLevel = .alert + 1
            window.makeKeyAndVisible()

            toastWindow = window

            // 👉 Einblend-Animation
            UIView.animate(withDuration: 0.3) {
                hosting.view.alpha = 1
            }

            // 👉 Ausblend-Animation + Cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                UIView.animate(withDuration: 0.3, animations: {
                    hosting.view.alpha = 0
                }) { _ in
                    toastWindow?.isHidden = true
                    toastWindow = nil
                }
            }
        }
    }
}

