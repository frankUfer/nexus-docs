//
//  RemoteCameraSession.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.04.25.
//

import Foundation
import MultipeerConnectivity
import UIKit

class RemoteCameraSession: NSObject, ObservableObject {
    private let serviceType = "cam-control"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var browser: MCNearbyServiceBrowser!
    private var session: MCSession!
    
    @Published var liveImage: UIImage? = nil
    @Published var isConnected: Bool = false
    
    override init() {
        super.init()
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }
    
    func sendCommand(_ command: String) {
        guard !session.connectedPeers.isEmpty else { return }
        if let data = command.data(using: .utf8) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }
    
    private func saveFile(name: String, from url: URL) {
        let _ = FileManagerHelper.shared.saveFile(named: name, from: url)
    }
}

// MARK: - Multipeer Delegates

extension RemoteCameraSession: MCSessionDelegate, MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.isConnected = (state == .connected)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let image = UIImage(data: data) {
            DispatchQueue.main.async {
                self.liveImage = image
            }
        }
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName name: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName name: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        guard let localURL = localURL else { return }
        saveFile(name: name, from: localURL)
    }

    func session(_: MCSession, didReceive: InputStream, withName: String, fromPeer: MCPeerID) {}
}
