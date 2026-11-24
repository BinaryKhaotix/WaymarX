//
//  WaymarXStartupRecoveryGate.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/23/26.
//


import SwiftUI

struct WaymarXStartupRecoveryGate<Content: View>: View {

    private enum StartupStatus {
        case checking
        case ready
        case interrupted(String)
        case failed(String)
    }

    let onReady: () -> Void
    let content: () -> Content

    @State private var status: StartupStatus = .checking

    init(
        onReady: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onReady = onReady
        self.content = content
    }

    var body: some View {
        Group {
            switch status {

            case .checking:
                VStack(spacing: 16) {
                    ProgressView()

                    Text("Checking WaymarX Recovery")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .ready:
                content()

            case .interrupted(let message):
                recoveryScreen(
                    title: "Restore Recovery Required",
                    message: message
                )

            case .failed(let message):
                recoveryScreen(
                    title: "Recovery Check Failed",
                    message: message
                )
            }
        }
        .task {
            checkRecoveryStatus()
        }
    }

    @MainActor
    private func checkRecoveryStatus() {
        
#if DEBUG
if ProcessInfo.processInfo.arguments.contains(
    "-WaymarXTestRecoveryGate"
) {
    print("🧪 Testing interrupted restore screen")

    status = .interrupted(
        """
        TEST MODE: An unfinished restoration was detected.

        Restore phase: committing

        Your saved data has not been modified.

        This is a simulated recovery warning.
        """
    )

    return
}
#endif

        do {
            let result = try WaymarXRestoreJournal.shared
                .inspectRecoveryStatus()

            switch result {

            case .clean:
                print("✅ WaymarX startup recovery check passed")

                status = .ready
                onReady()

            case .interrupted(let record):
                print("⚠️ WaymarX startup blocked")

                status = .interrupted(
                    """
                    An unfinished restoration was detected.

                    Restore phase: \(record.phase.rawValue)

                    Your saved data has not been automatically changed by recovery.

                    Please do not delete or reinstall WaymarX.
                    """
                )
            }

        } catch {
            print("❌ Recovery inspection failed: \(error)")

            status = .failed(
                """
                WaymarX could not verify the previous restoration state.

                \(error.localizedDescription)

                Your data has not been modified by this check.

                Do not delete or reinstall the app.
                """
            )
        }
    }

    private func recoveryScreen(
        title: String,
        message: String
    ) -> some View {

        VStack(spacing: 20) {

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(title)
                .font(.title2)
                .bold()

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text(
                "Recovery must be inspected before normal operation can resume."
            )
            .font(.footnote)
            .multilineTextAlignment(.center)

        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
