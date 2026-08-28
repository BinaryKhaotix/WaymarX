//
//  Extensions.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/20/24.
//

import Foundation

extension Notification.Name {
    static let popToRootView = Notification.Name("popToRootView")
}

extension UserDefaults {
    private static let addressUpdateKey = "didPerformAddressUpdate"

    var didPerformAddressUpdate: Bool {
        get {
            return self.bool(forKey: UserDefaults.addressUpdateKey)
        }
        set {
            self.set(newValue, forKey: UserDefaults.addressUpdateKey)
        }
    }
}

extension Sequence where Iterator.Element: Hashable {
    func uniqued() -> [Iterator.Element] {
        var seen = Set<Iterator.Element>()
        return filter { seen.insert($0).inserted }
    }
}
