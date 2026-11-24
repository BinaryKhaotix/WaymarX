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
        // MARK: - Storage Preflight

        try WaymarXStorageGuard.verifyAvailableSpace(
            forArchive: sourceURL
        )

        print("✅ Restore storage preflight passed")
        
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

        
        // MARK: - Verify Current Database Protection

        // The safety backup must represent the database
        // that is about to be replaced.
        let safetyMatchesCurrentDatabase =
            try manager.verifySafetyBackupAgainstCurrentDatabase(
                safetyBackupURL: safetyBackupURL,
                context: container.viewContext
            )

        guard safetyMatchesCurrentDatabase else {
            throw WaymarXRestoreError.invalidBackup(
                "The safety backup does not match the current database."
            )
        }

        // Ensure the local profile count has not changed
        // since preparation created the recovery journal.
        let currentUserCount = try container.viewContext.count(
            for: NSFetchRequest<NSFetchRequestResult>(
                entityName: "CrumbUser"
            )
        )

        guard currentUserCount == record.expectedUsers else {
            throw WaymarXRestoreError.invalidBackup(
                "The local profile count changed during preparation."
            )
        }

        print("✅ Pre-commit safety verification passed")

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
        guard record.phase == .readyToCommit ||
              record.phase == .committing else {
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

#if DEBUG && targetEnvironment(simulator)

extension WaymarXRestoreCoordinator {

    // Simulator-only finalization readiness check.
    // This function never deletes or modifies anything.

    func inspectCompletedRestoreForFinalization(
        container: NSPersistentContainer
    ) async throws -> WaymarXRecoveryInspection {

        let journal = WaymarXRestoreJournal.shared

        guard let record = try journal.load() else {
            throw WaymarXRestoreError.invalidBackup(
                "No restore journal exists."
            )
        }

        // Only a restore explicitly marked completed
        // is eligible for normal finalization.
        guard record.phase == .completed else {
            throw WaymarXRestoreError.invalidBackup(
                "Restore is not marked completed. Current phase: " +
                record.phase.rawValue
            )
        }

        guard !container.viewContext.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Unsaved Core Data changes prevent finalization."
            )
        }

        // The original safety backup must remain available.
        let safetyURL = record.safetyBackupURL

        guard FileManager.default.fileExists(
            atPath: safetyURL.path
        ) else {
            throw WaymarXRestoreError.invalidBackup(
                "The original safety backup is missing."
            )
        }

        // Confirm the safety archive is still readable.
        _ = try WaymarXRestoreManager.shared
            .validateArchive(at: safetyURL)

        // Inspect the current database against
        // the committed replacement manifest.
        guard let inspection = try await inspectPendingRestore(
            container: container
        ) else {
            throw WaymarXRestoreError.invalidBackup(
                "Recovery journal disappeared during inspection."
            )
        }

        guard inspection.databaseMatchesManifest else {
            throw WaymarXRestoreError.invalidBackup(
                "Database differs from the recovery manifest: " +
                inspection.problems.joined(separator: "; ")
            )
        }

        // Check the persisted expected counts explicitly.
        guard inspection.actualPins == record.expectedPins,
              inspection.actualGroups == record.expectedGroups,
              inspection.actualUsers == record.expectedUsers else {

            throw WaymarXRestoreError.invalidBackup(
                "Restored record counts do not match the journal."
            )
        }

        
        // MARK: - Verify Complete Restored Data

        let fullVerification =
            try await WaymarXRestoreManager.shared
                .verifyReplacementFromJournal(
                    record: record,
                    container: container
                )

        guard fullVerification.matchesBackup else {

            throw WaymarXRestoreError.invalidBackup(
                "Full recovery verification failed: " +
                fullVerification.problems.joined(separator: "; ")
            )
        }

        print("✅ Full database recovery verification passed")
        print(
            "Unique photographs verified: " +
            "\(fullVerification.photosVerified)"
        )

        
        print("✅ Completed restore passed manifest inspection")
        print("Pins: \(inspection.actualPins)")
        print("Groups: \(inspection.actualGroups)")
        print("Profiles: \(inspection.actualUsers)")
        print("Safety backup remains available")

        // IMPORTANT:
        // Do not clear the journal here.
        // Full-field and photo-content verification
        // must pass before final cleanup.

        return inspection
    }
}

#endif

#if DEBUG && targetEnvironment(simulator)

extension WaymarXRestoreCoordinator {

    func finalizeCompletedSimulatorRestore(
        container: NSPersistentContainer
    ) async throws {

        let journal = WaymarXRestoreJournal.shared

        guard let record = try journal.load() else {
            throw WaymarXRestoreError.invalidBackup(
                "No recovery journal exists to finalize."
            )
        }

        guard record.phase == .completed else {
            throw WaymarXRestoreError.invalidBackup(
                "Cannot finalize a restore in phase: " +
                record.phase.rawValue
            )
        }

        // Reuse the verified completed-restore inspector.
        // This checks the safety archive, manifest,
        // database fields and photograph contents.
        _ = try await inspectCompletedRestoreForFinalization(
            container: container
        )

        // Confirm the operation hasn't changed while
        // asynchronous verification was running.
        guard let latestRecord = try journal.load(),
              latestRecord.operationID == record.operationID,
              latestRecord.phase == .completed else {

            throw WaymarXRestoreError.invalidBackup(
                "Recovery journal changed during verification."
            )
        }

        guard !container.viewContext.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Unsaved changes prevent recovery finalization."
            )
        }

        // IMPORTANT:
        // Keep both the safety backup and staging files.
        // They provide an additional recovery source.
        //
        // The journal is the only file removed here.
        // This is permitted only after verification.

        try journal.clear()

        guard try !journal.hasPendingRestore else {
            throw WaymarXRestoreError.invalidBackup(
                "Recovery journal cleanup failed."
            )
        }

        print("✅ SIMULATOR RESTORE FINALIZED")
        print("✅ Full database verification passed")
        print("✅ Safety backup preserved")
        print("✅ Staging data preserved")
        print("✅ Recovery journal cleared")
    }
}

#endif

#if DEBUG && targetEnvironment(simulator)

extension WaymarXRestoreCoordinator {

    func recoverAbandonedSimulatorPreparation(
        container: NSPersistentContainer
    ) throws {

        let journal = WaymarXRestoreJournal.shared
        let manager = WaymarXRestoreManager.shared
        let fm = FileManager.default

        guard let record = try journal.load() else {
            throw WaymarXRestoreError.invalidBackup(
                "No recovery journal was found."
            )
        }

        // Never clean up a transaction that may
        // have started committing Core Data.
        guard record.phase == .readyToCommit ||
              record.phase == .committing else {

            throw WaymarXRestoreError.invalidBackup(
                "Automatic preparation cleanup is not permitted " +
                "for phase: \(record.phase.rawValue)"
            )
        }
        
        guard !container.viewContext.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Unsaved database changes prevent recovery."
            )
        }

        // Confirm the original database still matches
        // its verified safety backup.
        _ = try manager.verifySafetyBackupAgainstCurrentDatabase(
            safetyBackupURL: record.safetyBackupURL,
            context: container.viewContext
        )

        // Verify that the staging directory belongs
        // to the current WaymarX restore staging root.
        let support = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let stagingRoot = support
            .appendingPathComponent(
                "WaymarX/RestoreStaging",
                isDirectory: true
            )
            .standardizedFileURL

        let stagingFolder = record.stagingFolderURL
            .standardizedFileURL

        guard
            stagingFolder.deletingLastPathComponent() ==
                stagingRoot,
            UUID(
                uuidString: stagingFolder.lastPathComponent
            ) != nil
        else {
            throw WaymarXRestoreError.invalidBackup(
                "Unsafe recovery staging directory."
            )
        }

        // All registered preparation photographs
        // must agree with the completed photo manifest.
        let preparedNames = Set(record.preparedPhotoNames)
        let mappedNames = Set(
            record.photoFilenameMap.values
        )

        guard preparedNames == mappedNames,
              preparedNames.count ==
                  record.preparedPhotoNames.count else {

            throw WaymarXRestoreError.invalidBackup(
                "Recovery photograph manifest is inconsistent."
            )
        }

        let documents = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        // Validate every removal target BEFORE deleting
        // any photograph.
        var removablePhotos: [URL] = []

        for name in preparedNames {

            // Generated photo names begin with a UUID
            // followed by an underscore.
            let prefix = String(name.prefix(36))
            let suffix = name.dropFirst(36)

            guard UUID(uuidString: prefix) != nil,
                  suffix.first == "_",
                  suffix.count > 1,
                  !name.contains("/"),
                  !name.contains("\\"),
                  name != ".",
                  name != ".." else {

                throw WaymarXRestoreError.invalidBackup(
                    "Unsafe prepared photograph filename."
                )
            }

            let photo = documents
                .appendingPathComponent(name)
                .standardizedFileURL

            guard photo.deletingLastPathComponent() ==
                    documents.standardizedFileURL else {

                throw WaymarXRestoreError.invalidBackup(
                    "Prepared photograph escapes Documents."
                )
            }

            if fm.fileExists(atPath: photo.path) {

                let properties = try photo.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isSymbolicLinkKey
                    ]
                )

                guard properties.isRegularFile == true,
                      properties.isSymbolicLink != true else {

                    throw WaymarXRestoreError.invalidBackup(
                        "Invalid prepared photograph."
                    )
                }

                removablePhotos.append(photo)
            }
        }

        // Check the directory itself before removal.
        if fm.fileExists(atPath: stagingFolder.path) {

            let properties = try stagingFolder.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ]
            )

            guard properties.isDirectory == true,
                  properties.isSymbolicLink != true else {

                throw WaymarXRestoreError.invalidBackup(
                    "Invalid restore staging directory."
                )
            }
        }

        // No database transaction was started.
        // Remove only files registered by this
        // preparation operation.
        for photo in removablePhotos {
            try fm.removeItem(at: photo)
        }

        if fm.fileExists(atPath: stagingFolder.path) {
            try fm.removeItem(at: stagingFolder)
        }

        // Keep the original safety backup.

        // Clear journal LAST, after successful cleanup.
        try journal.clear()

        print("✅ ABANDONED PREPARATION RECOVERED")
        print("✅ Original database verified")
        print("✅ Prepared photographs cleaned")
        print("✅ Staging directory cleaned")
        print("✅ Safety backup retained")
        print("✅ Recovery journal cleared")
    }
}

#endif

#if DEBUG && targetEnvironment(simulator)

extension WaymarXRestoreCoordinator {

    func injectInterruptionBeforeDatabaseSave(
        sourceURL: URL,
        safetyBackupURL: URL,
        container: NSPersistentContainer
    ) throws {

        let manager = WaymarXRestoreManager.shared
        let journal = WaymarXRestoreJournal.shared

        guard try !journal.hasPendingRestore else {
            throw WaymarXRestoreError.invalidBackup(
                "A restore journal already exists."
            )
        }

        guard !container.viewContext.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Save pending changes before testing."
            )
        }

        // Prove the safety backup represents
        // the original, current database.
        _ = try manager
            .verifySafetyBackupAgainstCurrentDatabase(
                safetyBackupURL: safetyBackupURL,
                context: container.viewContext
            )

        // Run actual preparation without
        // modifying the Core Data database.
        let transaction = try manager
            .prepareRestoreTransaction(
                from: sourceURL,
                safetyBackupURL: safetyBackupURL
            )

        guard let record = try journal.load(),
              record.phase == .readyToCommit,
              record.expectedPins ==
                  transaction.staged.backup.breadcrumbs.count,
              record.expectedGroups ==
                  transaction.staged.backup.groups.count else {

            throw WaymarXRestoreError.invalidBackup(
                "Prepared restore journal is inconsistent."
            )
        }

        // Simulate reaching the commit boundary.
        // DO NOT perform the Core Data replacement.
        try journal.updatePhase(.committing)

        print("🧪 INTERRUPT BEFORE DATABASE SAVE")
        print("Journal phase: committing")
        print("Original database remains unchanged")
        print("Stop WaymarX in Xcode now")
    }
}

#endif

#if DEBUG && targetEnvironment(simulator)

extension WaymarXRestoreCoordinator {

    func injectInterruptionAfterDatabaseSave(
        sourceURL: URL,
        safetyBackupURL: URL,
        container: NSPersistentContainer
    ) async throws -> WaymarXRestoreResult {

        let manager = WaymarXRestoreManager.shared
        let journal = WaymarXRestoreJournal.shared

        // Do not run while recovery is already pending.
        guard try !journal.hasPendingRestore else {
            throw WaymarXRestoreError.invalidBackup(
                "A previous restoration requires recovery."
            )
        }

        guard !container.viewContext.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Save pending changes before testing."
            )
        }

        // Check storage before creating the transaction.
        try WaymarXStorageGuard.verifyAvailableSpace(
            forArchive: sourceURL
        )

        // Validate the existing recovery copy.
        _ = try manager
            .verifySafetyBackupAgainstCurrentDatabase(
                safetyBackupURL: safetyBackupURL,
                context: container.viewContext
            )

        // Prepare the replacement and create the journal.
        let transaction = try manager.prepareRestoreTransaction(
            from: sourceURL,
            safetyBackupURL: safetyBackupURL
        )

        guard let record = try journal.load(),
              record.phase == .readyToCommit else {

            throw WaymarXRestoreError.invalidBackup(
                "Restore preparation did not finish."
            )
        }

        // Confirm that the persistent manifest matches
        // the data we're actually about to commit.
        let pinIDs = Set(
            transaction.staged.backup.breadcrumbs.map(
                \.backupID
            )
        )

        let groupIDs = Set(
            transaction.staged.backup.groups.map(
                \.id
            )
        )

        guard Set(record.expectedPinIDs) == pinIDs,
              Set(record.expectedGroupIDs) == groupIDs,
              record.photoFilenameMap ==
                  transaction.preparedPhotos.filenameMap else {

            throw WaymarXRestoreError.invalidBackup(
                "Prepared replacement manifest differs."
            )
        }

        // Recheck the original database immediately
        // before the destructive transaction.
        _ = try manager
            .verifySafetyBackupAgainstCurrentDatabase(
                safetyBackupURL: safetyBackupURL,
                context: container.viewContext
            )

        let currentUserCount = try container.viewContext.count(
            for: NSFetchRequest<NSFetchRequestResult>(
                entityName: "CrumbUser"
            )
        )

        guard currentUserCount == record.expectedUsers else {
            throw WaymarXRestoreError.invalidBackup(
                "Local profile count changed before commit."
            )
        }

        // Write commit intention BEFORE replacing Core Data.
        try journal.updatePhase(.committing)

        print("🧪 TEST B: COMMITTING DATABASE")

        // This is the REAL database replacement.
        let result = try await
            manager.commitStagedReplacementInSimulator(
                staged: transaction.staged,
                prepared: transaction.preparedPhotos,
                container: container
            )

        // INTENTIONAL INTERRUPTION POINT:
        //
        // Core Data save has returned successfully.
        // Do NOT advance journal to verifying/completed.
        // Do NOT clear the journal.
        //
        // The next cold launch must inspect the
        // already-replaced database.

        print("🧪 TEST B: DATABASE SAVE RETURNED")
        print("Pins: \(result.pins)")
        print("Groups: \(result.groups)")
        print("Profiles: \(result.users)")
        print("Photos: \(result.photos)")
        print("Journal deliberately remains committing")
        print("STOP THE APP IN XCODE NOW")

        return result
    }
}

#endif
