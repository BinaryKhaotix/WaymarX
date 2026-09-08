//
//  ContextualTipManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/3/26.
//

import Foundation
import SwiftUI

@MainActor
final class ContextualTipManager: ObservableObject {

    static let shared = ContextualTipManager()

    @Published var activeTip: ContextualTip?

    private init() {}

    func showIfNeeded(_ tip: ContextualTip) {

        let key = storageKey(for: tip)

        guard !UserDefaults.standard.bool(forKey: key) else {
            return
        }

        guard activeTip == nil else {
            return
        }

        activeTip = tip
    }

    func dismissActiveTip() {

        guard let tip = activeTip else {
            return
        }

        let key = storageKey(for: tip)

        UserDefaults.standard.set(
            true,
            forKey: key
        )

        activeTip = nil
    }

    func resetTip(_ tip: ContextualTip) {

        UserDefaults.standard.removeObject(
            forKey: storageKey(for: tip)
        )
    }
    
    func resetAllTips() {

        resetTip(.arrivalNotificationActions)

        resetTip(.wantToGoPromotion)

        resetTip(.backupRestore)

        resetTip(.unsavedPins)
    }

    private func storageKey(
        for tip: ContextualTip
    ) -> String {

        "contextualTip.\(tip.id).shown"
    }
}
