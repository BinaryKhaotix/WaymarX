//
//  WaymarXRestorePresentation.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/24/26.
//


import Foundation
import Combine

@MainActor
final class WaymarXRestorePresentation: ObservableObject {
    
    static let shared = WaymarXRestorePresentation()
    
    @Published private(set) var isRestoring = false
    @Published private(set) var statusMessage = ""
    @Published private(set) var handoffURL: URL?
    
    private init() {}
    
    func begin() {
        isRestoring = true
        statusMessage = "Preparing restoration..."
        
        print("🔒 WaymarX restore interface activated")
    }
    
    func beginPreparedRestore(handoffURL: URL) {
        
        guard !isRestoring else {
            print("⚠️ Restore interface already active")
            return
        }
        
        self.handoffURL = handoffURL
        
        begin()
        
        updateStatus(
            "Restore archive preserved and verified."
        )
        
        print("✅ Restore handoff transferred to presentation")
    }
    
    func updateStatus(_ message: String) {
        guard isRestoring else { return }
        statusMessage = message
        
        print("🔄 Restore: \(message)")
    }
    
    func finish() {
        
        handoffURL = nil
        statusMessage = ""
        isRestoring = false
        
        print("🔓 WaymarX restore interface released")
    }
}
