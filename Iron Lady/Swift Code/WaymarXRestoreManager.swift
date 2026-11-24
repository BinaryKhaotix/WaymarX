//
//  WaymarXRestoreManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/23/26.
//


import Foundation
import AppleArchive
import System
import CoreData

struct WaymarXRestorePreview {
    let pinCount: Int
    let groupCount: Int
    let userCount: Int
    let photoReferences: Int
    let photosFound: Int
    let photosMissing: Int
    let createdAt: Date
    let appVersion: String
}

enum WaymarXRestoreError: LocalizedError {
    case unsupportedFormat
    case missingBackupJSON
    case invalidBackup(String)
    case missingPhotoDirectory

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This backup format is not supported."
        case .missingBackupJSON:
            return "The archive does not contain backup.json."
        case .invalidBackup(let reason):
            return "Invalid backup: \(reason)"
        case .missingPhotoDirectory:
            return "The backup's photos directory is missing."
        }
    }
}

final class WaymarXRestoreManager {

    static let shared = WaymarXRestoreManager()

    private init() {}

    // MARK: - Validate Backup

    func validateArchive(
        at sourceURL: URL
    ) throws -> WaymarXRestorePreview {

        let accessed = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default

        let temporaryFolder = fileManager.temporaryDirectory
            .appendingPathComponent(
                "WaymarX_Validation_\(UUID().uuidString)",
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: temporaryFolder,
            withIntermediateDirectories: true
        )

        defer {
            try? fileManager.removeItem(at: temporaryFolder)
        }

        // Extract the compressed AppleArchive.
        try extractArchive(
            from: sourceURL,
            to: temporaryFolder
        )

        // Find backup.json, including within a nested folder.
        guard let enumerator = fileManager.enumerator(
            at: temporaryFolder,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            throw WaymarXRestoreError.missingBackupJSON
        }

        var jsonURL: URL?

        for case let url as URL in enumerator {
            if url.lastPathComponent == "backup.json" {
                guard jsonURL == nil else {
                    throw WaymarXRestoreError.invalidBackup(
                        "Multiple backup.json files were found."
                    )
                }
                jsonURL = url
            }
        }

        guard let jsonURL else {
            throw WaymarXRestoreError.missingBackupJSON
        }

        let data = try Data(contentsOf: jsonURL)

        let backup = try BackupManager.shared.decodeBackup(
            from: data
        )

        // MARK: Validate Schema

        guard backup.backupFormatVersion == 1 else {
            throw WaymarXRestoreError.unsupportedFormat
        }

        let groupIDs = backup.groups.map(\.id)

        guard Set(groupIDs).count == groupIDs.count else {
            throw WaymarXRestoreError.invalidBackup(
                "Duplicate group identifiers."
            )
        }

        let pinIDs = backup.breadcrumbs.map(\.backupID)

        guard Set(pinIDs).count == pinIDs.count else {
            throw WaymarXRestoreError.invalidBackup(
                "Duplicate pin identifiers."
            )
        }

        let validGroups = Set(groupIDs)

        for pin in backup.breadcrumbs {
            guard pin.latitude.isFinite,
                  pin.longitude.isFinite,
                  (-90...90).contains(pin.latitude),
                  (-180...180).contains(pin.longitude) else {
                throw WaymarXRestoreError.invalidBackup(
                    "Invalid coordinates for a saved pin."
                )
            }

            if let groupID = pin.groupID,
               !validGroups.contains(groupID) {
                throw WaymarXRestoreError.invalidBackup(
                    "A pin references a missing group."
                )
            }

            if let radius = pin.arrivalRadius,
               (!radius.isFinite || radius < 0) {
                throw WaymarXRestoreError.invalidBackup(
                    "A pin has an invalid arrival radius."
                )
            }
        }

        // MARK: Validate Photographs

        let photoNames = Set(
            backup.breadcrumbs.compactMap { pin -> String? in
                guard let name = pin.photoURL?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else {
                    return nil
                }
                return name
            }
        )

        let photosFolder = jsonURL
            .deletingLastPathComponent()
            .appendingPathComponent("photos", isDirectory: true)

        if !photoNames.isEmpty &&
           !fileManager.fileExists(atPath: photosFolder.path) {
            throw WaymarXRestoreError.missingPhotoDirectory
        }

        var photosFound = 0
        var photosMissing = 0

        for name in photoNames {

            // Photo references should be filenames, not paths.
            let safeName = URL(fileURLWithPath: name).lastPathComponent

            guard safeName == name, name != ".", name != ".." else {
                throw WaymarXRestoreError.invalidBackup(
                    "Unsafe photo filename."
                )
            }

            let photoURL = photosFolder.appendingPathComponent(name)

            var isDirectory: ObjCBool = false

            if fileManager.fileExists(
                atPath: photoURL.path,
                isDirectory: &isDirectory
            ) && !isDirectory.boolValue {
                photosFound += 1
            } else {
                photosMissing += 1
            }
        }

        return WaymarXRestorePreview(
            pinCount: backup.breadcrumbs.count,
            groupCount: backup.groups.count,
            userCount: backup.users.count,
            photoReferences: photoNames.count,
            photosFound: photosFound,
            photosMissing: photosMissing,
            createdAt: backup.createdAt,
            appVersion: backup.appVersion
        )
    }

    // MARK: - Extract AppleArchive

    fileprivate func extractArchive(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws {

        let sourcePath = FilePath(sourceURL.path)
        let destinationPath = FilePath(destinationURL.path)

        try ArchiveByteStream.withFileStream(
            path: sourcePath,
            mode: .readOnly,
            options: [],
            permissions: [.ownerReadWrite]
        ) { fileStream in

            try ArchiveByteStream.withDecompressionStream(
                readingFrom: fileStream
            ) { decompressionStream in

                try ArchiveStream.withDecodeStream(
                    readingFrom: decompressionStream
                ) { decodeStream in

                    try ArchiveStream.withExtractStream(
                        extractingTo: destinationPath
                    ) { extractStream in

                        _ = try ArchiveStream.process(
                            readingFrom: decodeStream,
                            writingTo: extractStream
                        )
                    }
                }
            }
        }
    }
}


import CoreData

struct WaymarXRestoreResult {
    let pins: Int
    let groups: Int
    let users: Int
    let photos: Int
}

extension WaymarXRestoreManager {

    @MainActor
    func restoreToEmptySimulator(
        at sourceURL: URL,
        context: NSManagedObjectContext
    ) throws -> WaymarXRestoreResult {

        #if targetEnvironment(simulator)

        let fm = FileManager.default

        // Never import over existing or pending data.
        guard !context.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "Core Data has unsaved changes. Restart the app."
            )
        }

        func recordCount(_ entity: String) throws -> Int {
            try context.count(
                for: NSFetchRequest<NSFetchRequestResult>(
                    entityName: entity
                )
            )
        }

        guard try recordCount("Breadcrumb") == 0,
              try recordCount("CrmGroup") == 0,
              try recordCount("CrumbUser") == 0 else {
            throw WaymarXRestoreError.invalidBackup(
                "The simulator database is not empty. Restore cancelled."
            )
        }

        // Validate the entire archive first.
        let preview = try validateArchive(at: sourceURL)

        guard preview.photosMissing == 0 else {
            throw WaymarXRestoreError.invalidBackup(
                "\(preview.photosMissing) photographs are missing."
            )
        }

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let staging = fm.temporaryDirectory
            .appendingPathComponent(
                "WaymarX_Restore_\(UUID().uuidString)",
                isDirectory: true
            )

        try fm.createDirectory(
            at: staging,
            withIntermediateDirectories: true
        )

        defer {
            try? fm.removeItem(at: staging)
        }

        try extractArchive(from: sourceURL, to: staging)

        // Locate the JSON within the extracted package.
        guard let enumerator = fm.enumerator(
            at: staging,
            includingPropertiesForKeys: nil
        ) else {
            throw WaymarXRestoreError.missingBackupJSON
        }

        var jsonFiles: [URL] = []

        for case let url as URL in enumerator {
            if url.lastPathComponent == "backup.json" {
                jsonFiles.append(url)
            }
        }

        guard jsonFiles.count == 1,
              let jsonURL = jsonFiles.first else {
            throw WaymarXRestoreError.invalidBackup(
                "Expected exactly one backup.json file."
            )
        }

        let backup = try BackupManager.shared.decodeBackup(
            from: Data(contentsOf: jsonURL)
        )

        guard backup.backupFormatVersion == 1,
              backup.breadcrumbs.count == preview.pinCount,
              backup.groups.count == preview.groupCount,
              backup.users.count == preview.userCount else {
            throw WaymarXRestoreError.invalidBackup(
                "Backup validation counts do not match."
            )
        }

        let photoFolder = jsonURL.deletingLastPathComponent()
            .appendingPathComponent("photos", isDirectory: true)

        let documents = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let photoNames = Set(
            backup.breadcrumbs.compactMap { $0.photoURL }
                .filter { !$0.isEmpty }
        )

        // Check every destination before writing any files.
        for name in photoNames {
            guard !name.isEmpty,
                  name != ".",
                  name != "..",
                  !name.contains("/"),
                  !name.contains("\\"),
                  URL(fileURLWithPath: name).lastPathComponent == name
            else {
                throw WaymarXRestoreError.invalidBackup(
                    "Unsafe photograph filename: \(name)"
                )
            }

            let source = photoFolder.appendingPathComponent(name)
            let destination = documents.appendingPathComponent(name)

            var isDirectory: ObjCBool = false

            guard fm.fileExists(
                atPath: source.path,
                isDirectory: &isDirectory
            ), !isDirectory.boolValue else {
                throw WaymarXRestoreError.invalidBackup(
                    "Missing photograph: \(name)"
                )
            }

            guard !fm.fileExists(atPath: destination.path) else {
                throw WaymarXRestoreError.invalidBackup(
                    "A photograph already exists: \(name)"
                )
            }
        }

        var copiedPhotos: [URL] = []
        var databaseSaved = false

        do {
            // Copy photos before saving Core Data.
            for name in photoNames.sorted() {
                let source = photoFolder.appendingPathComponent(name)
                let destination = documents.appendingPathComponent(name)

                try fm.copyItem(at: source, to: destination)
                copiedPhotos.append(destination)
            }

            // Create groups first.
            var groupsByID: [UUID: CrmGroup] = [:]

            for item in backup.groups {
                let group = CrmGroup(context: context)

                group.id = item.id
                group.groupName = item.groupName
                group.groupDescription = item.groupDescription
                group.dateCreated = item.dateCreated

                groupsByID[item.id] = group
            }

            // Create all breadcrumbs.
            for item in backup.breadcrumbs {
                let pin = Breadcrumb(context: context)

                pin.id = item.backupID
                pin.dateDropped = item.dateDropped
                pin.latitude = item.latitude
                pin.longitude = item.longitude
                pin.name = item.name
                pin.note = item.note
                pin.isFavorite = item.isFavorite
                pin.streetAddress = item.streetAddress
                pin.city = item.city
                pin.state = item.state
                pin.zipCode = item.zipCode
                pin.photoURL = item.photoURL
                pin.isWantToGo = item.isWantToGo
                pin.wantToGoDate = item.wantToGoDate
                pin.visitedDate = item.visitedDate

                pin.arrivalRadius = item.arrivalRadius.map {
                    NSNumber(value: $0)
                }

                if let groupID = item.groupID {
                    guard let group = groupsByID[groupID] else {
                        throw WaymarXRestoreError.invalidBackup(
                            "A breadcrumb references an unknown group."
                        )
                    }

                    pin.crmGroup = group
                }
            }

            // Restore profiles, deliberately excluding passwords.
            for item in backup.users {
                let user = CrumbUser(context: context)

                user.username = item.username
                user.name = item.name
                user.address = item.address
                user.phoneNumber = item.phoneNumber
                user.homeLatitude = item.homeLatitude
                user.homeLongitude = item.homeLongitude
                user.profilePicture = item.profilePicture
            }

            // Verify the inserted records before committing.
            context.processPendingChanges()

            guard try recordCount("Breadcrumb") == preview.pinCount,
                  try recordCount("CrmGroup") == preview.groupCount,
                  try recordCount("CrumbUser") == preview.userCount else {
                throw WaymarXRestoreError.invalidBackup(
                    "Inserted Core Data counts do not match the backup."
                )
            }

            try context.save()
            databaseSaved = true

        } catch {
            if !databaseSaved {
                context.rollback()

                for url in copiedPhotos {
                    try? fm.removeItem(at: url)
                }
            }

            throw error
        }

        // Verify the saved database.
        guard try recordCount("Breadcrumb") == preview.pinCount,
              try recordCount("CrmGroup") == preview.groupCount,
              try recordCount("CrumbUser") == preview.userCount else {
            throw WaymarXRestoreError.invalidBackup(
                "The saved database counts do not match."
            )
        }

        print("✅ WaymarX Restore Completed")
        print("Pins: \(preview.pinCount)")
        print("Groups: \(preview.groupCount)")
        print("Profiles: \(preview.userCount)")
        print("Photos: \(copiedPhotos.count)")

        return WaymarXRestoreResult(
            pins: preview.pinCount,
            groups: preview.groupCount,
            users: preview.userCount,
            photos: copiedPhotos.count
        )

        #else

        throw WaymarXRestoreError.invalidBackup(
            "This experimental restore is simulator-only."
        )

        #endif
    }
}

struct WaymarXSafetyBackupResult {
    let fileURL: URL
    let preview: WaymarXRestorePreview
}

extension WaymarXRestoreManager {

    @MainActor
    func createSafetyBackup(
        context: NSManagedObjectContext
    ) throws -> WaymarXSafetyBackupResult {

        let fm = FileManager.default

        // Save pending changes before creating the snapshot.
        if context.hasChanges {
            try context.save()
        }

        // Create the archive using our existing backup engine.
        let result = try BackupManager.shared.createBackupArchive(
            context: context
        )

        let temporaryArchive = result.fileURL

        defer {
            try? fm.removeItem(at: temporaryArchive)
        }

        // Keep safety backups in persistent Application Support,
        // not the system temporary directory.
        let supportURL = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let safetyFolder = supportURL
            .appendingPathComponent(
                "WaymarX/SafetyBackups",
                isDirectory: true
            )

        try fm.createDirectory(
            at: safetyFolder,
            withIntermediateDirectories: true
        )

        let filename = "Safety_\(UUID().uuidString).waymarxbackup"

        let destinationURL = safetyFolder
            .appendingPathComponent(filename)

        // Copy the archive to persistent storage.
        try fm.copyItem(
            at: temporaryArchive,
            to: destinationURL
        )

        do {
            // Validate the saved copy, not just the temporary original.
            let preview = try validateArchive(at: destinationURL)

            guard preview.pinCount == result.pinCount,
                  preview.groupCount == result.groupCount,
                  preview.photoReferences == result.photoReferences,
                  preview.photosFound == result.photosCopied,
                  preview.photosMissing == 0,
                  result.photosMissing == 0 else {
                throw WaymarXRestoreError.invalidBackup(
                    "The safety backup failed verification."
                )
            }

            print("✅ Safety Backup Verified")
            print("Pins: \(preview.pinCount)")
            print("Groups: \(preview.groupCount)")
            print("Photos: \(preview.photosFound)")
            print("Saved: \(destinationURL.path)")

            return WaymarXSafetyBackupResult(
                fileURL: destinationURL,
                preview: preview
            )

        } catch {
            // Do not retain a failed safety backup.
            try? fm.removeItem(at: destinationURL)
            throw error
        }
    }
}


struct WaymarXStagedRestore {
    let folderURL: URL
    let backup: WaymarXBackup
    let photoFolderURL: URL
    let preview: WaymarXRestorePreview
}

extension WaymarXRestoreManager {

    func stageReplacement(
        from sourceURL: URL
    ) throws -> WaymarXStagedRestore {

        let fm = FileManager.default

        // Validate the source archive before staging.
        let preview = try validateArchive(at: sourceURL)

        guard preview.photosMissing == 0 else {
            throw WaymarXRestoreError.invalidBackup(
                "The backup contains missing photographs."
            )
        }

        let supportURL = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let stagingRoot = supportURL
            .appendingPathComponent(
                "WaymarX/RestoreStaging",
                isDirectory: true
            )

        try fm.createDirectory(
            at: stagingRoot,
            withIntermediateDirectories: true
        )

        let stagingFolder = stagingRoot
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        try fm.createDirectory(
            at: stagingFolder,
            withIntermediateDirectories: true
        )

        do {
            try extractArchive(
                from: sourceURL,
                to: stagingFolder
            )

            guard let enumerator = fm.enumerator(
                at: stagingFolder,
                includingPropertiesForKeys: [.isRegularFileKey]
            ) else {
                throw WaymarXRestoreError.missingBackupJSON
            }

            var jsonFiles: [URL] = []

            for case let url as URL in enumerator {
                if url.lastPathComponent == "backup.json" {
                    jsonFiles.append(url)
                }
            }

            guard jsonFiles.count == 1,
                  let jsonURL = jsonFiles.first else {
                throw WaymarXRestoreError.invalidBackup(
                    "Expected exactly one backup.json file."
                )
            }

            let backup = try BackupManager.shared.decodeBackup(
                from: Data(contentsOf: jsonURL)
            )

            guard backup.backupFormatVersion == 1,
                  backup.breadcrumbs.count == preview.pinCount,
                  backup.groups.count == preview.groupCount,
                  backup.users.count == preview.userCount else {
                throw WaymarXRestoreError.invalidBackup(
                    "Staged backup does not match validation."
                )
            }

            let photosFolder = jsonURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "photos",
                    isDirectory: true
                )

            // Validate all photo references before proceeding.
            let photoNames = Set(
                backup.breadcrumbs.compactMap { $0.photoURL }
                    .filter { !$0.isEmpty }
            )

            for name in photoNames {
                guard name != ".",
                      name != "..",
                      !name.contains("/"),
                      !name.contains("\\"),
                      URL(fileURLWithPath: name)
                          .lastPathComponent == name else {
                    throw WaymarXRestoreError.invalidBackup(
                        "Unsafe photograph filename."
                    )
                }

                let photoURL = photosFolder
                    .appendingPathComponent(name)

                let values = try photoURL.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isSymbolicLinkKey
                    ]
                )

                guard values.isRegularFile == true,
                      values.isSymbolicLink != true else {
                    throw WaymarXRestoreError.invalidBackup(
                        "Invalid or missing photograph: \(name)"
                    )
                }
            }

            print("✅ Replacement archive staged")
            print("Pins: \(backup.breadcrumbs.count)")
            print("Groups: \(backup.groups.count)")
            print("Photos: \(photoNames.count)")

            return WaymarXStagedRestore(
                folderURL: stagingFolder,
                backup: backup,
                photoFolderURL: photosFolder,
                preview: preview
            )

        } catch {
            try? fm.removeItem(at: stagingFolder)
            throw error
        }
    }

    func discardStagedReplacement(
        _ staged: WaymarXStagedRestore
    ) throws {
        try FileManager.default.removeItem(
            at: staged.folderURL
        )
    }
}


struct WaymarXPreparedPhotos {

    // Maps original photo filenames to new filenames.
    let filenameMap: [String: String]

    // Files created during this preparation.
    let copiedFiles: [URL]
}

extension WaymarXRestoreManager {

    func prepareReplacementPhotos(
        from staged: WaymarXStagedRestore
    ) throws -> WaymarXPreparedPhotos {

        let fm = FileManager.default

        let documents = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let photoNames = Set(
            staged.backup.breadcrumbs
                .compactMap { $0.photoURL }
                .filter { !$0.isEmpty }
        )

        var filenameMap: [String: String] = [:]
        var copiedFiles: [URL] = []

        do {
            for originalName in photoNames.sorted() {

                // Recheck the filename before filesystem access.
                guard originalName != ".",
                      originalName != "..",
                      !originalName.contains("/"),
                      !originalName.contains("\\"),
                      URL(fileURLWithPath: originalName)
                          .lastPathComponent == originalName else {

                    throw WaymarXRestoreError.invalidBackup(
                        "Unsafe photograph filename."
                    )
                }

                let sourceURL = staged.photoFolderURL
                    .appendingPathComponent(originalName)

                let values = try sourceURL.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isSymbolicLinkKey
                    ]
                )

                guard values.isRegularFile == true,
                      values.isSymbolicLink != true else {

                    throw WaymarXRestoreError.invalidBackup(
                        "Invalid photograph: \(originalName)"
                    )
                }

                // Unique prefix avoids filename collisions.
                let newFilename =
                    "\(UUID().uuidString)_\(originalName)"

                let destinationURL = documents
                    .appendingPathComponent(newFilename)

                // Never overwrite an existing file.
                guard !fm.fileExists(
                    atPath: destinationURL.path
                ) else {
                    throw WaymarXRestoreError.invalidBackup(
                        "Photograph filename collision."
                    )
                }

                // Register the destination BEFORE creating the file.
                // This lets restart recovery identify interrupted copies.
                try WaymarXRestoreJournal.shared.registerPlannedPhoto(
                    newFilename
                )
                
                try fm.copyItem(
                    at: sourceURL,
                    to: destinationURL
                )

                // Track files so failures can be cleaned up.
                copiedFiles.append(destinationURL)

                filenameMap[originalName] = newFilename
            }

            print("✅ Replacement photos prepared")
            print("Photos copied: \(copiedFiles.count)")

            return WaymarXPreparedPhotos(
                filenameMap: filenameMap,
                copiedFiles: copiedFiles
            )

        } catch {

            // Remove only files created by this attempt.
            for fileURL in copiedFiles {
                try? fm.removeItem(at: fileURL)
            }

            throw error
        }
    }

    func discardPreparedPhotos(
        _ prepared: WaymarXPreparedPhotos
    ) throws {

        let fm = FileManager.default

        for fileURL in prepared.copiedFiles {
            if fm.fileExists(atPath: fileURL.path) {
                try fm.removeItem(at: fileURL)
            }
        }
    }
}

extension WaymarXRestoreManager {

    @MainActor
    func commitStagedReplacementInSimulator(
        staged: WaymarXStagedRestore,
        prepared: WaymarXPreparedPhotos,
        container: NSPersistentContainer
    ) async throws -> WaymarXRestoreResult {

        #if targetEnvironment(simulator)

        let viewContext = container.viewContext

        // Do not replace records while the UI has unsaved edits.
        guard !viewContext.hasChanges else {
            throw WaymarXRestoreError.invalidBackup(
                "There are unsaved changes. Save them before restoring."
            )
        }

        let fm = FileManager.default
        let documents = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let backup = staged.backup
        let preview = staged.preview

        // Verify every incoming photo has a prepared replacement.
        let originalPhotoNames = Set(
            backup.breadcrumbs
                .compactMap { $0.photoURL }
                .filter { !$0.isEmpty }
        )

        guard Set(prepared.filenameMap.keys) == originalPhotoNames,
              Set(prepared.filenameMap.values).count ==
                originalPhotoNames.count else {

            throw WaymarXRestoreError.invalidBackup(
                "Prepared photograph mapping is incomplete."
            )
        }

        for name in prepared.filenameMap.values {
            let url = documents.appendingPathComponent(name)

            let properties = try url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )

            guard properties.isRegularFile == true,
                  properties.isSymbolicLink != true else {

                throw WaymarXRestoreError.invalidBackup(
                    "A prepared photograph is missing or invalid."
                )
            }
        }

        let context = container.newBackgroundContext()
        context.mergePolicy = NSErrorMergePolicy
        context.undoManager = nil

        let result = try await context.perform {
            () throws -> WaymarXRestoreResult in

            func count(_ entity: String) throws -> Int {
                try context.count(
                    for: NSFetchRequest<NSFetchRequestResult>(
                        entityName: entity
                    )
                )
            }

            do {
                // Delete existing records in this private context.
                // Nothing is committed until context.save().
                for entity in [
                    "Breadcrumb",
                    "CrmGroup",
                    "CrumbUser"
                ] {
                    let request = NSFetchRequest<NSManagedObject>(
                        entityName: entity
                    )

                    let existing = try context.fetch(request)

                    for object in existing {
                        context.delete(object)
                    }
                }

                // Restore groups.
                var groupsByID: [UUID: CrmGroup] = [:]

                for item in backup.groups {
                    let group = CrmGroup(context: context)

                    group.id = item.id
                    group.dateCreated = item.dateCreated
                    group.groupName = item.groupName
                    group.groupDescription = item.groupDescription

                    groupsByID[item.id] = group
                }

                // Restore pins.
                for item in backup.breadcrumbs {
                    let pin = Breadcrumb(context: context)

                    pin.id = item.backupID
                    pin.dateDropped = item.dateDropped
                    pin.latitude = item.latitude
                    pin.longitude = item.longitude
                    pin.name = item.name
                    pin.note = item.note
                    pin.isFavorite = item.isFavorite

                    pin.streetAddress = item.streetAddress
                    pin.city = item.city
                    pin.state = item.state
                    pin.zipCode = item.zipCode

                    pin.isWantToGo = item.isWantToGo
                    pin.wantToGoDate = item.wantToGoDate
                    pin.visitedDate = item.visitedDate

                    pin.arrivalRadius = item.arrivalRadius.map {
                        NSNumber(value: $0)
                    }

                    if let oldPhoto = item.photoURL,
                       !oldPhoto.isEmpty {

                        guard let newPhoto =
                                prepared.filenameMap[oldPhoto] else {

                            throw WaymarXRestoreError.invalidBackup(
                                "Missing photograph mapping."
                            )
                        }

                        pin.photoURL = newPhoto
                    } else {
                        pin.photoURL = nil
                    }

                    if let groupID = item.groupID {
                        guard let group = groupsByID[groupID] else {
                            throw WaymarXRestoreError.invalidBackup(
                                "A pin references an unknown group."
                            )
                        }

                        pin.crmGroup = group
                    }
                }

                // Restore profiles without passwords.
                for item in backup.users {
                    let user = CrumbUser(context: context)

                    user.username = item.username
                    user.name = item.name
                    user.address = item.address
                    user.phoneNumber = item.phoneNumber
                    user.homeLatitude = item.homeLatitude
                    user.homeLongitude = item.homeLongitude
                    user.profilePicture = item.profilePicture
                }

                // Evaluate changes before saving.
                context.processPendingChanges()

                guard try count("Breadcrumb") == preview.pinCount,
                      try count("CrmGroup") == preview.groupCount,
                      try count("CrumbUser") == preview.userCount else {

                    throw WaymarXRestoreError.invalidBackup(
                        "Replacement record counts do not match."
                    )
                }

                // Single transaction for the Core Data changes.
                try context.save()

                return WaymarXRestoreResult(
                    pins: preview.pinCount,
                    groups: preview.groupCount,
                    users: preview.userCount,
                    photos: prepared.filenameMap.count
                )

            } catch {
                context.rollback()
                throw error
            }
        }

        // Allow the UI context to pick up committed changes.
        // We will add explicit view refresh handling when wiring UI.
        viewContext.refreshAllObjects()

        return result

        #else

        throw WaymarXRestoreError.invalidBackup(
            "Database replacement is currently simulator-only."
        )

        #endif
    }
}

struct WaymarXPreparedRestoreTransaction {

    let staged: WaymarXStagedRestore
    let preparedPhotos: WaymarXPreparedPhotos
    let safetyBackupURL: URL
}

extension WaymarXRestoreManager {

    func prepareRestoreTransaction(
        from sourceURL: URL,
        safetyBackupURL: URL
    ) throws -> WaymarXPreparedRestoreTransaction {

        let fm = FileManager.default
        let journal = WaymarXRestoreJournal.shared

        // Never start a second restore while another
        // restore journal still exists.
        guard try !journal.hasPendingRestore else {
            throw WaymarXRestoreError.invalidBackup(
                "An unfinished restore already exists. Recovery is required."
            )
        }

        // The recovery backup must exist and be readable.
        guard fm.fileExists(atPath: safetyBackupURL.path) else {
            throw WaymarXRestoreError.invalidBackup(
                "The safety backup is missing."
            )
        }

        let safetyPreview = try validateArchive(
            at: safetyBackupURL
        )

        guard safetyPreview.photosMissing == 0 else {
            throw WaymarXRestoreError.invalidBackup(
                "The safety backup contains missing photographs."
            )
        }

        // Stage the replacement without touching
        // the active Core Data database.
        let staged = try stageReplacement(
            from: sourceURL
        )

        // Do not remove staged files after the journal
        // is created. Recovery may need them.
        do {
            let record = WaymarXRestoreJournalRecord(
                stagingFolderURL: staged.folderURL,
                safetyBackupURL: safetyBackupURL,
                preview: staged.preview
            )

            try journal.save(record)

        } catch {
            try? fm.removeItem(at: staged.folderURL)
            throw error
        }

        // prepareReplacementPhotos registers each
        // destination filename before copying.
        //
        // On failure, retain the journal so recovery
        // can inspect any incomplete operation.
        let preparedPhotos = try prepareReplacementPhotos(
            from: staged
        )

        try journal.updatePhase(.photosPrepared)

        // Verify all prepared photo references.
        guard preparedPhotos.filenameMap.count ==
                staged.preview.photoReferences else {

            throw WaymarXRestoreError.invalidBackup(
                "Prepared photograph count does not match the backup."
            )
        }
        try journal.recordReplacementManifest(
            backup: staged.backup,
            filenameMap: preparedPhotos.filenameMap
        )
        try journal.updatePhase(.readyToCommit)

        print("✅ Restore transaction prepared")
        print("Pins: \(staged.preview.pinCount)")
        print("Groups: \(staged.preview.groupCount)")
        print("Photos: \(preparedPhotos.filenameMap.count)")
        print("🛡️ Original database has not been modified")

        return WaymarXPreparedRestoreTransaction(
            staged: staged,
            preparedPhotos: preparedPhotos,
            safetyBackupURL: safetyBackupURL
        )
    }
}


struct WaymarXDatabaseVerification {

    let pins: Int
    let groups: Int
    let users: Int
    let photosVerified: Int

    let matchesBackup: Bool
    let problems: [String]
}

extension WaymarXRestoreManager {

    @MainActor
    func verifyReplacementDatabase(
        staged: WaymarXStagedRestore,
        prepared: WaymarXPreparedPhotos,
        container: NSPersistentContainer
    ) async throws -> WaymarXDatabaseVerification {

        let backup = staged.backup
        let filenameMap = prepared.filenameMap

        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let context = container.newBackgroundContext()
        context.undoManager = nil

        return try await context.perform {

            let fm = FileManager.default
            var problems: [String] = []
            var photosVerified = 0

            // Read the actual persisted records.
            let pins = try context.fetch(
                NSFetchRequest<Breadcrumb>(
                    entityName: "Breadcrumb"
                )
            )

            let groups = try context.fetch(
                NSFetchRequest<CrmGroup>(
                    entityName: "CrmGroup"
                )
            )

            let users = try context.fetch(
                NSFetchRequest<CrumbUser>(
                    entityName: "CrumbUser"
                )
            )

            // MARK: - Verify Counts

            if pins.count != backup.breadcrumbs.count {
                problems.append("Pin count does not match.")
            }

            if groups.count != backup.groups.count {
                problems.append("Group count does not match.")
            }

            if users.count != backup.users.count {
                problems.append("Profile count does not match.")
            }

            // MARK: - Verify Group Identifiers

            let expectedGroupIDs = Set(
                backup.groups.map(\.id)
            )

            let actualGroupIDs = Set(
                groups.compactMap(\.id)
            )

            if actualGroupIDs != expectedGroupIDs {
                problems.append(
                    "Group identifiers do not match."
                )
            }

            // MARK: - Verify Pin Identifiers

            let expectedPinIDs = Set(
                backup.breadcrumbs.map(\.backupID)
            )

            let actualPinIDs = Set(
                pins.compactMap(\.id)
            )

            if actualPinIDs != expectedPinIDs {
                problems.append(
                    "Pin identifiers do not match."
                )
            }

            // MARK: - Verify Individual Pins

            var actualPinsByID: [UUID: Breadcrumb] = [:]

            for pin in pins {

                guard let id = pin.id else {
                    problems.append(
                        "A saved pin has no identifier."
                    )
                    continue
                }

                if actualPinsByID[id] != nil {
                    problems.append(
                        "Duplicate pin identifier: \(id)"
                    )
                    continue
                }

                actualPinsByID[id] = pin
            }

            for expected in backup.breadcrumbs {

                guard let actual = actualPinsByID[
                    expected.backupID
                ] else {
                    problems.append(
                        "Missing pin: \(expected.backupID)"
                    )
                    continue
                }

                // Verify saved coordinates.
                if actual.latitude != expected.latitude ||
                   actual.longitude != expected.longitude {

                    problems.append(
                        "Coordinates differ for pin: \(expected.backupID)"
                    )
                }

                // Verify group relationship.
                if actual.crmGroup?.id != expected.groupID {
                    problems.append(
                        "Group relationship differs for pin: \(expected.backupID)"
                    )
                }

                // Verify photograph filename mapping.
                let originalPhoto = expected.photoURL

                let expectedPhoto: String?

                if let originalPhoto,
                   !originalPhoto.isEmpty {
                    expectedPhoto = filenameMap[originalPhoto]

                    if expectedPhoto == nil {
                        problems.append(
                            "Missing photo mapping for pin: \(expected.backupID)"
                        )
                    }
                } else {
                    expectedPhoto = nil
                }

                if actual.photoURL != expectedPhoto {
                    problems.append(
                        "Photo reference differs for pin: \(expected.backupID)"
                    )
                    continue
                }

                // Verify the photograph exists on disk.
                if let expectedPhoto {

                    let photoURL = documents
                        .appendingPathComponent(expectedPhoto)

                    if let properties = try? photoURL.resourceValues(
                        forKeys: [
                            .isRegularFileKey,
                            .isSymbolicLinkKey
                        ]
                    ),
                    properties.isRegularFile == true,
                    properties.isSymbolicLink != true {

                        photosVerified += 1

                    } else {
                        problems.append(
                            "Photograph missing or invalid: \(expectedPhoto)"
                        )
                    }
                }
            }

            // MARK: - Results

            let matches = problems.isEmpty

            if matches {
                print("✅ WaymarX database verification passed")
            } else {
                print("❌ WaymarX database verification failed")

                for problem in problems {
                    print("  \(problem)")
                }
            }

            return WaymarXDatabaseVerification(
                pins: pins.count,
                groups: groups.count,
                users: users.count,
                photosVerified: photosVerified,
                matchesBackup: matches,
                problems: problems
            )
        }
    }
}

struct WaymarXRecoveryInspection {

    let databaseMatchesManifest: Bool
    let actualPins: Int
    let actualGroups: Int
    let actualUsers: Int
    let problems: [String]
}

extension WaymarXRestoreManager {

    func inspectDatabaseAgainstJournal(
        record: WaymarXRestoreJournalRecord,
        container: NSPersistentContainer
    ) async throws -> WaymarXRecoveryInspection {

        let context = container.newBackgroundContext()
        context.undoManager = nil

        return try await context.perform {

            var problems: [String] = []

            let pins = try context.fetch(
                NSFetchRequest<Breadcrumb>(
                    entityName: "Breadcrumb"
                )
            )

            let groups = try context.fetch(
                NSFetchRequest<CrmGroup>(
                    entityName: "CrmGroup"
                )
            )

            let users = try context.fetch(
                NSFetchRequest<CrumbUser>(
                    entityName: "CrumbUser"
                )
            )

            // MARK: - Verify Counts

            if pins.count != record.expectedPins {
                problems.append("Pin count differs.")
            }

            if groups.count != record.expectedGroups {
                problems.append("Group count differs.")
            }

            if users.count != record.expectedUsers {
                problems.append("Profile count differs.")
            }

            // MARK: - Verify Manifest Completeness

            if record.expectedPinIDs.count != record.expectedPins {
                problems.append("Pin manifest is incomplete.")
            }

            if record.expectedGroupIDs.count != record.expectedGroups {
                problems.append("Group manifest is incomplete.")
            }

            // MARK: - Verify Identifiers

            let actualPinIDs = pins.compactMap(\.id)
            let actualGroupIDs = groups.compactMap(\.id)

            if Set(actualPinIDs).count != pins.count {
                problems.append("Duplicate or missing pin IDs.")
            }

            if Set(actualGroupIDs).count != groups.count {
                problems.append("Duplicate or missing group IDs.")
            }

            if Set(record.expectedPinIDs).count !=
                record.expectedPinIDs.count {
                problems.append("Duplicate expected pin IDs.")
            }

            if Set(record.expectedGroupIDs).count !=
                record.expectedGroupIDs.count {
                problems.append("Duplicate expected group IDs.")
            }

            if Set(actualPinIDs) != Set(record.expectedPinIDs) {
                problems.append("Pin identifiers differ.")
            }

            if Set(actualGroupIDs) != Set(record.expectedGroupIDs) {
                problems.append("Group identifiers differ.")
            }

            // MARK: - Verify Photograph References

            let mappedNames = Array(
                record.photoFilenameMap.values
            )

            if Set(mappedNames).count != mappedNames.count {
                problems.append("Duplicate mapped photograph names.")
            }

            let expectedPhotos = Set(mappedNames)

            let actualPhotos = Set(
                pins.compactMap { $0.photoURL }
                    .filter { !$0.isEmpty }
            )

            if actualPhotos != expectedPhotos {
                problems.append(
                    "Database photograph references differ."
                )
            }

            // MARK: - Verify Photograph Files

            let fm = FileManager.default

            let documents = fm.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]

            for filename in expectedPhotos {

                guard filename != ".",
                      filename != "..",
                      !filename.contains("/"),
                      !filename.contains("\\") else {

                    problems.append(
                        "Unsafe photograph reference in journal."
                    )
                    continue
                }

                let url = documents
                    .appendingPathComponent(filename)

                guard let values = try? url.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isSymbolicLinkKey
                    ]
                ),
                values.isRegularFile == true,
                values.isSymbolicLink != true else {

                    problems.append(
                        "Missing or invalid restored photograph: \(filename)"
                    )
                    continue
                }
            }

            // MARK: - Return Inspection

            let matches = problems.isEmpty

            if matches {
                print("✅ Database matches recovery manifest")
            } else {
                print("⚠️ Database differs from recovery manifest")

                for problem in problems {
                    print("  \(problem)")
                }
            }

            return WaymarXRecoveryInspection(
                databaseMatchesManifest: matches,
                actualPins: pins.count,
                actualGroups: groups.count,
                actualUsers: users.count,
                problems: problems
            )
        }
    }
}
