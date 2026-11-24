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
            await checkRecoveryStatus()
        }
    }


    @MainActor
    private func checkRecoveryStatus() async {

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(
            "-WaymarXTestRecoveryGate"
        ) {
            print("🧪 Testing interrupted restore screen")

            status = .interrupted(
                """
                TEST MODE: An unfinished restoration was detected.

                Restore phase: committing

                This is a simulated recovery warning.
                No restoration was performed.
                """
            )

            return
        }
        #endif

        do {
            let journal = WaymarXRestoreJournal.shared

            let result = try journal.inspectRecoveryStatus()

            switch result {

            case .clean:

                print("✅ WaymarX startup recovery check passed")

                status = .ready
                onReady()

            case .interrupted(let record):

                print("⚠️ Restore journal detected")
                print("Phase: \(record.phase.rawValue)")

                switch record.phase {

                case .preparing, .photosPrepared, .readyToCommit:

                    // No commit should have started in these phases.
                    // Leave the journal intact until cleanup is verified.

                    status = .interrupted(
                        """
                        A restoration was interrupted before
                        the database replacement began.

                        Restore phase: \(record.phase.rawValue)

                        Recovery cleanup is required.

                        No automatic database changes
                        have been made.
                        """
                    )
                    
                    
                case .completed:

                    #if DEBUG && targetEnvironment(simulator)

                    print("🔍 Verifying completed simulator restore")

                    try await WaymarXRestoreCoordinator.shared
                        .finalizeCompletedSimulatorRestore(
                            container: PersistenceController.shared.container
                        )

                    print("✅ Completed restore recovery finalized")

                    status = .ready
                    onReady()

                    #else

                    // Production does not yet automatically clear
                    // completed restore journals.
                    status = .interrupted(
                        """
                        A completed restoration requires
                        final recovery verification.

                        No recovery changes have been made.
                        """
                    )

                    #endif


                case .committing, .verifying:

                    // The database may already have changed.
                    // Inspect its actual records before making
                    // any recovery decision.

                    let inspection =
                        try await WaymarXRestoreCoordinator.shared
                            .inspectPendingRestore(
                                container:
                                    PersistenceController.shared.container
                            )

                    guard let inspection else {
                        status = .failed(
                            """
                            The restore journal disappeared
                            during recovery inspection.

                            No recovery changes were made.
                            """
                        )
                        return
                    }

                    if inspection.databaseMatchesManifest {

                        print(
                            "✅ Recovery database matches manifest"
                        )

                        status = .interrupted(
                            """
                            A previous restoration was detected.

                            Restore phase: \(record.phase.rawValue)

                            The database matches the recorded
                            replacement manifest.

                            Pins: \(inspection.actualPins)
                            Groups: \(inspection.actualGroups)
                            Profiles: \(inspection.actualUsers)

                            Final recovery verification and
                            cleanup are still required.

                            No automatic database changes
                            have been made.
                            """
                        )

                    } else {

                        print(
                            "❌ Recovery database does not match manifest"
                        )

                        let details = inspection.problems
                            .prefix(5)
                            .joined(separator: "\n")

                        status = .failed(
                            """
                            A restoration was interrupted and
                            the database does not match the
                            expected replacement.

                            Restore phase: \(record.phase.rawValue)

                            \(details)

                            Do not delete or reinstall WaymarX.

                            Recovery requires further inspection.
                            """
                        )
                    }
                }
            }

        } catch {

            print("❌ Recovery inspection failed: \(error)")

            status = .failed(
                """
                WaymarX could not verify the previous
                restoration state.

                \(error.localizedDescription)

                No recovery changes were made.

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
