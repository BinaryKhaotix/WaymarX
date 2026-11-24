//
//  WaymarXRestoreCoordinator.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/23/26.
//


import Foundation
import CoreData

struct WaymarXRestoreExecutionResult {
    let restoration: WaymarXRestoreResult
    let verification: WaymarXDatabaseVerification
}

@MainActor
final class WaymarXRestoreCoordinator {

    static let shared = WaymarXRestoreCoordinator()

    private init() {}

    // MARK: - Simulator Replacement Test

    func executeSimulatorReplacement(
        sourceURL: URL,
        safetyBackupURL: URL,
        container: NSPersistentContainer
    ) async throws -> WaymarXRestoreExecutionResult {

        #if targetEnvironment(simulator)

        let manager = WaymarXRestoreManager.shared
        let journal = WaymarXRestoreJournal.shared

        // Do not begin while another restore is pending.
        guard try !journal.hasPendingRestore else {
            throw WaymarXRestoreError.invalidBackup(
                "An unfinished restoration requires recovery."
            )
        }

        // Do not begin with unsaved UI changes.
        guard !container.viewContext.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Save existing changes before restoring."
            )
        }

        // MARK: - Prepare

        let transaction = try manager.prepareRestoreTransaction(
            from: sourceURL,
            safetyBackupURL: safetyBackupURL
        )

        // Preparation has created a persistent journal.
        // Do not automatically remove it after a failure.

        // MARK: - Confirm Manifest

        guard let record = try journal.load(),
              record.phase == .readyToCommit else {
            throw WaymarXRestoreError.invalidBackup(
                "Replacement journal is not ready to commit."
            )
        }

        let expectedPinIDs = Set(
            transaction.staged.backup.breadcrumbs.map(\.backupID)
        )

        let expectedGroupIDs = Set(
            transaction.staged.backup.groups.map(\.id)
        )

        guard Set(record.expectedPinIDs) == expectedPinIDs,
              Set(record.expectedGroupIDs) == expectedGroupIDs,
              record.photoFilenameMap ==
                  transaction.preparedPhotos.filenameMap else {

            throw WaymarXRestoreError.invalidBackup(
                "Replacement manifest failed verification."
            )
        }

        // MARK: - Record Commit Intention

        // This must happen BEFORE the database save.
        try journal.updatePhase(.committing)

        // MARK: - Commit Core Data

        let restoration =
            try await manager.commitStagedReplacementInSimulator(
                staged: transaction.staged,
                prepared: transaction.preparedPhotos,
                container: container
            )

        // MARK: - Verify Database

        try journal.updatePhase(.verifying)

        let verification =
            try await manager.verifyReplacementDatabase(
                staged: transaction.staged,
                prepared: transaction.preparedPhotos,
                container: container
            )

        guard verification.matchesBackup else {
            throw WaymarXRestoreError.invalidBackup(
                "The restored database failed verification: " +
                verification.problems.joined(separator: "; ")
            )
        }

        // MARK: - Record Completion

        try journal.updatePhase(.completed)

        print("✅ WaymarX replacement transaction completed")
        print("Pins: \(restoration.pins)")
        print("Groups: \(restoration.groups)")
        print("Profiles: \(restoration.users)")
        print("Photos: \(restoration.photos)")

        // Intentionally retain the recovery journal.
        // Final cleanup requires restart verification.

        return WaymarXRestoreExecutionResult(
            restoration: restoration,
            verification: verification
        )

        #else

        throw WaymarXRestoreError.invalidBackup(
            "Replacement testing is simulator-only."
        )

        #endif
    }
}

extension WaymarXRestoreCoordinator {

    func inspectPendingRestore(
        container: NSPersistentContainer
    ) async throws -> WaymarXRecoveryInspection? {

        let journal = WaymarXRestoreJournal.shared

        // No journal means no restore awaiting inspection.
        guard let record = try journal.load() else {
            print("✅ No pending restore to inspect")
            return nil
        }

        print("🔍 Inspecting WaymarX recovery state")
        print("Phase: \(record.phase.rawValue)")

        let inspection = try await
            WaymarXRestoreManager.shared
                .inspectDatabaseAgainstJournal(
                    record: record,
                    container: container
                )

        if inspection.databaseMatchesManifest {

            print("✅ Database matches recovery manifest")
            print("Pins: \(inspection.actualPins)")
            print("Groups: \(inspection.actualGroups)")
            print("Profiles: \(inspection.actualUsers)")

        } else {

            print("⚠️ Recovery inspection found differences")

            for problem in inspection.problems {
                print("  \(problem)")
            }
        }

        // Read-only inspection.
        // Do not clear the journal or modify the database.
        return inspection
    }
}
