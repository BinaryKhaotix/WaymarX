//
//  WaymarXRestoreJournal.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/23/26.
//



import Foundation

// MARK: - Restore Phases

enum WaymarXRestorePhase: String, Codable {
    case preparing
    case photosPrepared
    case readyToCommit
    case committing
    case verifying
    case completed
}

// MARK: - Persistent Restore Record

struct WaymarXRestoreJournalRecord: Codable {

    let journalFormatVersion: Int
    let operationID: UUID
    let createdAt: Date

    var phase: WaymarXRestorePhase

    // Recovery locations.
    var stagingFolderURL: URL
    var safetyBackupURL: URL
    
    // Expected database counts.
    let expectedPins: Int
    let expectedGroups: Int
    let expectedUsers: Int

    // Photographs registered before copying.
    var preparedPhotoNames: [String]

    // Expected database identities.
    var expectedPinIDs: [UUID]
    var expectedGroupIDs: [UUID]

    // Original filename -> restored filename.
    var photoFilenameMap: [String: String]

    init(
        stagingFolderURL: URL,
        safetyBackupURL: URL,
        preview: WaymarXRestorePreview,
        preservedUserCount: Int
    ) {
        self.journalFormatVersion = 1
        self.operationID = UUID()
        self.createdAt = Date()
        self.phase = .preparing

        self.stagingFolderURL = stagingFolderURL
        self.safetyBackupURL = safetyBackupURL

        self.expectedPins = preview.pinCount
        self.expectedGroups = preview.groupCount
        self.expectedUsers = preservedUserCount

        self.preparedPhotoNames = []
        self.expectedPinIDs = []
        self.expectedGroupIDs = []
        self.photoFilenameMap = [:]
    }
}

// MARK: - Recovery Status

enum WaymarXRecoveryStatus {
    case clean
    case interrupted(WaymarXRestoreJournalRecord)
}

// MARK: - Restore Journal Manager

final class WaymarXRestoreJournal {

    static let shared = WaymarXRestoreJournal()

    private init() {}

    // MARK: - Journal Location

    private var journalURL: URL {
        get throws {

            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let folder = support.appendingPathComponent(
                "WaymarX/RestoreRecovery",
                isDirectory: true
            )

            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

            return folder.appendingPathComponent(
                "active-restore.json"
            )
        }
    }

    private func resolveRecoveryPaths(
        in record: WaymarXRestoreJournalRecord
    ) throws -> WaymarXRestoreJournalRecord {

        var resolved = record

        // The journal is stored at:
        // Application Support/WaymarX/RestoreRecovery/active-restore.json

        // Resolve paths relative to the CURRENT app container.
        let waymarxFolder = try journalURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let stagingName =
            record.stagingFolderURL.lastPathComponent

        let safetyName =
            record.safetyBackupURL.lastPathComponent

        // Do not allow arbitrary paths from journal data.
        guard UUID(uuidString: stagingName) != nil else {
            throw WaymarXRestoreError.invalidBackup(
                "Invalid recovery staging folder identifier."
            )
        }

        guard safetyName.hasPrefix("Safety_"),
              safetyName.hasSuffix(".waymarxbackup") else {
            throw WaymarXRestoreError.invalidBackup(
                "Invalid recovery safety backup filename."
            )
        }

        let safetyID = String(
            safetyName
                .dropFirst("Safety_".count)
                .dropLast(".waymarxbackup".count)
        )

        guard UUID(uuidString: safetyID) != nil else {
            throw WaymarXRestoreError.invalidBackup(
                "Invalid recovery safety backup identifier."
            )
        }

        resolved.stagingFolderURL = waymarxFolder
            .appendingPathComponent(
                "RestoreStaging",
                isDirectory: true
            )
            .appendingPathComponent(
                stagingName,
                isDirectory: true
            )

        resolved.safetyBackupURL = waymarxFolder
            .appendingPathComponent(
                "SafetyBackups",
                isDirectory: true
            )
            .appendingPathComponent(safetyName)

        return resolved
    }

    // MARK: - Load Journal

    func load() throws -> WaymarXRestoreJournalRecord? {

        let url = try journalURL

        guard FileManager.default.fileExists(
            atPath: url.path
        ) else {
            return nil
        }

        let data = try Data(contentsOf: url)

        let record = try JSONDecoder().decode(
            WaymarXRestoreJournalRecord.self,
            from: data
        )

        guard record.journalFormatVersion == 1 else {
            throw WaymarXRestoreError.invalidBackup(
                "Unsupported restore journal version: \(record.journalFormatVersion)"
            )
        }

        return try resolveRecoveryPaths(in: record)
    }

    // MARK: - Save Journal

    func save(
        _ record: WaymarXRestoreJournalRecord
    ) throws {

        let url = try journalURL

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        let data = try encoder.encode(record)

        try data.write(
            to: url,
            options: .atomic
        )

        print(
            "🛡️ Restore journal saved: \(record.phase.rawValue)"
        )
    }

    // MARK: - Update Phase

    func updatePhase(
        _ phase: WaymarXRestorePhase
    ) throws {

        guard var record = try load() else {
            throw WaymarXRestoreError.invalidBackup(
                "No active restore journal exists."
            )
        }

        record.phase = phase

        try save(record)
    }

    // MARK: - Update Prepared Photos

    func updatePreparedPhotos(
        _ filenames: [String]
    ) throws {

        guard var record = try load() else {
            throw WaymarXRestoreError.invalidBackup(
                "No active restore journal exists."
            )
        }

        record.preparedPhotoNames = filenames.sorted()

        try save(record)
    }

    // MARK: - Register Planned Photograph

    func registerPlannedPhoto(
        _ filename: String
    ) throws {

        guard var record = try load() else {
            throw WaymarXRestoreError.invalidBackup(
                "Cannot prepare photographs without an active restore journal."
            )
        }

        guard record.phase == .preparing ||
              record.phase == .photosPrepared else {

            throw WaymarXRestoreError.invalidBackup(
                "Photograph preparation is not allowed in this restore phase."
            )
        }

        guard !record.preparedPhotoNames.contains(filename) else {
            throw WaymarXRestoreError.invalidBackup(
                "Photograph is already registered."
            )
        }

        record.preparedPhotoNames.append(filename)

        // Record the filename BEFORE copying the file.
        try save(record)
    }

    // MARK: - Record Replacement Manifest

    func recordReplacementManifest(
        backup: WaymarXBackup,
        filenameMap: [String: String]
    ) throws {

        guard var record = try load() else {
            throw WaymarXRestoreError.invalidBackup(
                "No active restore journal exists."
            )
        }

        guard record.phase == .photosPrepared else {
            throw WaymarXRestoreError.invalidBackup(
                "Restore is not ready to record its manifest."
            )
        }

        let pinIDs = backup.breadcrumbs.map(\.backupID)
        let groupIDs = backup.groups.map(\.id)

        guard Set(pinIDs).count == pinIDs.count,
              Set(groupIDs).count == groupIDs.count else {

            throw WaymarXRestoreError.invalidBackup(
                "Duplicate identifiers in replacement backup."
            )
        }

        let referencedPhotos = Set(
            backup.breadcrumbs
                .compactMap { $0.photoURL }
                .filter { !$0.isEmpty }
        )

        guard Set(filenameMap.keys) == referencedPhotos,
              Set(filenameMap.values).count == referencedPhotos.count,
              Set(filenameMap.values).isSubset(
                  of: Set(record.preparedPhotoNames)
              ) else {

            throw WaymarXRestoreError.invalidBackup(
                "Replacement photograph manifest is incomplete."
            )
        }

        record.expectedPinIDs = pinIDs.sorted {
            $0.uuidString < $1.uuidString
        }

        record.expectedGroupIDs = groupIDs.sorted {
            $0.uuidString < $1.uuidString
        }

        record.photoFilenameMap = filenameMap

        try save(record)

        print("✅ Replacement manifest recorded")
    }

    // MARK: - Pending Restore

    var hasPendingRestore: Bool {
        get throws {
            try load() != nil
        }
    }

    // MARK: - Inspect Recovery Status

    func inspectRecoveryStatus() throws -> WaymarXRecoveryStatus {

        // A corrupt journal must throw, not be treated as clean.
        guard let record = try load() else {
            print("✅ WaymarX: No interrupted restore found")
            return .clean
        }

        print("⚠️ WaymarX: Interrupted restore detected")
        print("Operation: \(record.operationID)")
        print("Phase: \(record.phase.rawValue)")
        print("Started: \(record.createdAt)")

        let fm = FileManager.default

        let stagingExists = fm.fileExists(
            atPath: record.stagingFolderURL.path
        )

        let safetyBackupExists = fm.fileExists(
            atPath: record.safetyBackupURL.path
        )

        print("Staging exists: \(stagingExists)")
        print("Safety backup exists: \(safetyBackupExists)")
        print(
            "Registered photographs: \(record.preparedPhotoNames.count)"
        )

        return .interrupted(record)
    }

    // MARK: - Clear Journal

    func clear() throws {

        let url = try journalURL

        if FileManager.default.fileExists(
            atPath: url.path
        ) {
            try FileManager.default.removeItem(
                at: url
            )
        }
    }

} // End WaymarXRestoreJournal
