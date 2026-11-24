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

#if DEBUG && targetEnvironment(simulator)

struct WaymarXPreparationTestResult {
    let originalPins: Int
    let originalGroups: Int
    let originalUsers: Int
    let stagedPins: Int
    let stagedGroups: Int
    let preparedPhotos: Int
}

extension WaymarXRestoreCoordinator {

    func testRestorePreparation(
        sourceURL: URL,
        safetyBackupURL: URL,
        context: NSManagedObjectContext
    ) throws -> WaymarXPreparationTestResult {

        let manager = WaymarXRestoreManager.shared
        let journal = WaymarXRestoreJournal.shared

        guard !context.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Save pending changes before testing."
            )
        }

        guard try !journal.hasPendingRestore else {
            throw WaymarXRestoreError.invalidBackup(
                "An unfinished restore journal already exists."
            )
        }

        // Capture actual Core Data object identities.
        // These let us detect deleted or inserted objects.
        func snapshot(_ entity: String) throws -> Set<NSManagedObjectID> {
            let request = NSFetchRequest<NSManagedObject>(
                entityName: entity
            )
            return Set(try context.fetch(request).map(\.objectID))
        }

        let originalPins = try snapshot("Breadcrumb")
        let originalGroups = try snapshot("CrmGroup")
        let originalUsers = try snapshot("CrumbUser")

        print("🧪 STARTING JOURNAL PREPARATION TEST")

        // This prepares data and photos but does NOT commit Core Data.
        let transaction = try manager.prepareRestoreTransaction(
            from: sourceURL,
            safetyBackupURL: safetyBackupURL
        )

        // Verify the journal.
        guard let record = try journal.load() else {
            throw WaymarXRestoreError.invalidBackup(
                "Preparation did not create a journal."
            )
        }

        let backup = transaction.staged.backup
        let prepared = transaction.preparedPhotos

        let expectedPinIDs = Set(backup.breadcrumbs.map(\.backupID))
        let expectedGroupIDs = Set(backup.groups.map(\.id))

        guard record.phase == .readyToCommit,
              Set(record.expectedPinIDs) == expectedPinIDs,
              Set(record.expectedGroupIDs) == expectedGroupIDs,
              record.photoFilenameMap == prepared.filenameMap,
              Set(record.preparedPhotoNames) ==
                  Set(prepared.filenameMap.values),
              prepared.filenameMap.count == 11 else {

            throw WaymarXRestoreError.invalidBackup(
                "Journal or photograph manifest verification failed."
            )
        }

        // Verify every prepared photograph exists.
        let fm = FileManager.default

        for url in prepared.copiedFiles {
            let values = try url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )

            guard values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                throw WaymarXRestoreError.invalidBackup(
                    "A prepared photograph is missing or invalid."
                )
            }
        }

        // Verify Core Data was not replaced.
        guard try snapshot("Breadcrumb") == originalPins,
              try snapshot("CrmGroup") == originalGroups,
              try snapshot("CrumbUser") == originalUsers,
              !context.hasChanges else {

            throw WaymarXRestoreError.invalidBackup(
                "Core Data identities changed during preparation."
            )
        }

        // Only a pre-commit operation may be cleaned up here.
        guard record.phase == .readyToCommit else {
            throw WaymarXRestoreError.invalidBackup(
                "Refusing cleanup after a possible database commit."
            )
        }

        // Remove only files created during THIS preparation.
        // Keep the verified safety backup.
        try manager.discardPreparedPhotos(prepared)

        try manager.discardStagedReplacement(
            transaction.staged
        )

        // Clear the journal LAST.
        try journal.clear()

        guard try !journal.hasPendingRestore else {
            throw WaymarXRestoreError.invalidBackup(
                "Test cleanup did not clear the journal."
            )
        }

        print("✅ JOURNAL PREPARATION TEST PASSED")
        print("Original pins: \(originalPins.count)")
        print("Original groups: \(originalGroups.count)")
        print("Prepared photos: \(prepared.copiedFiles.count)")
        print("Recovery journal cleaned up")
        print("Original Core Data records unchanged")

        return WaymarXPreparationTestResult(
            originalPins: originalPins.count,
            originalGroups: originalGroups.count,
            originalUsers: originalUsers.count,
            stagedPins: backup.breadcrumbs.count,
            stagedGroups: backup.groups.count,
            preparedPhotos: prepared.copiedFiles.count
        )
    }
}

#endif
