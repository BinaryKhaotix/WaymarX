//
//  WaymarXDatabaseAccessGate.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/24/26.
//


import Foundation

@MainActor
final class WaymarXDatabaseAccessGate {

    static let shared = WaymarXDatabaseAccessGate()

    private(set) var restoreRequested = false

    private var activeOperations = 0
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []

    private init() {}

    var allowsNewOperations: Bool {
        !restoreRequested
    }

    func beginOperation() -> Bool {
        guard !restoreRequested else {
            return false
        }

        activeOperations += 1
        return true
    }

    func endOperation() {
        precondition(
            activeOperations > 0,
            "Unbalanced database operation."
        )

        activeOperations -= 1

        if activeOperations == 0 {
            let waiters = drainWaiters
            drainWaiters.removeAll()

            for waiter in waiters {
                waiter.resume()
            }
        }
    }
    
    func requestRestore() {
        restoreRequested = true

        print("🔒 WaymarX database access closed")
    }
    
    func waitForOperationsToDrain() async {
        guard restoreRequested else {
            return
        }

        guard activeOperations > 0 else {
            print("✅ Database operations already drained")
            return
        }

        print(
            "⏳ Waiting for \(activeOperations) database operation(s)"
        )

        await withCheckedContinuation { continuation in
            drainWaiters.append(continuation)
        }

        print("✅ Registered database operations drained")
    }

    var isDrained: Bool {
        activeOperations == 0
    }

    func releaseAfterVerifiedRecovery() {
        precondition(
            activeOperations == 0,
            "Cannot release database gate with active operations."
        )

        restoreRequested = false

        print("🔓 WaymarX database access reopened")
    }
}
