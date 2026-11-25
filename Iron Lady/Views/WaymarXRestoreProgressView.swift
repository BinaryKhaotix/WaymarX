//
//  WaymarXRestoreProgressView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/24/26.
//



import SwiftUI

struct WaymarXRestoreProgressView: View {

    @ObservedObject var presentation:
        WaymarXRestorePresentation

    @State private var restoreStarted = false
    @State private var restoreFailed = false
    @State private var failureMessage = ""
    @State private var restoreCompleted = false

    var body: some View {

        VStack(spacing: 24) {

            Spacer()

            Image(systemName: "externaldrive.badge.shield.half.filled")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Restoring WaymarX")
                .font(.title2)
                .bold()

            if restoreCompleted {

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

            } else if restoreFailed {

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

            } else {

                ProgressView()
                    .controlSize(.large)
                    .padding(.vertical, 12)
            }
            
            Text(presentation.statusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)

            if restoreFailed {
                Text(failureMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(
                "Do not close WaymarX while restoration is running."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Spacer()

            Label(
                "Your safety backup is preserved.",
                systemImage: "shield.checkered"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .task {
            await performRestore()
        }
    }

    @MainActor
    private func performRestore() async {

        guard !restoreStarted else { return }
        restoreStarted = true

        guard let handoffURL = presentation.handoffURL else {
            restoreFailed = true
            failureMessage = "No restore archive was provided."
            presentation.updateStatus("Restore cannot begin.")
            return
        }

        // Yield so SwiftUI can render the restore screen
        // before the database operation begins.
        await Task.yield()

        do {
            #if DEBUG && targetEnvironment(simulator)

            let result = try await WaymarXRestoreCoordinator.shared
                .executeCoordinatedSimulatorRestore(
                    handoffURL: handoffURL,
                    container: PersistenceController.shared.container
                )
            
            restoreCompleted = true

            presentation.updateStatus(
                """
                Restoration completed successfully.

                Pins: \(result.restoration.pins)
                Groups: \(result.restoration.groups)
                Photos: \(result.restoration.photos)

                Restart WaymarX to finish recovery.
                """
            )

            #else

            throw WaymarXRestoreError.invalidBackup(
                "Production restoration is not enabled."
            )

            #endif
            
            presentation.updateStatus(
                """
                Restoration completed successfully.

                Pins: \(result.restoration.pins)
                Groups: \(result.restoration.groups)
                Photos: \(result.restoration.photos)

                Restart WaymarX to finish recovery.
                """
            )

        } catch {
            restoreFailed = true
            failureMessage = error.localizedDescription

            presentation.updateStatus(
                """
                Restoration requires inspection.

                Do not reinstall WaymarX.
                """
            )

            print("❌ Coordinated restore failed: \(error)")
        }
    }
}
