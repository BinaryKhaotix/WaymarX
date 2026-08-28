//
//  BackupManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/21/26.
//

import Foundation
import CoreData
import AppleArchive
import System

struct WaymarXBackupPackageResult {
    let folderURL: URL
    let pinCount: Int
    let groupCount: Int
    let photoReferences: Int
    let photosCopied: Int
    let photosMissing: Int
}

struct WaymarXArchiveResult {
    let fileURL: URL
    let pinCount: Int
    let groupCount: Int
    let photoReferences: Int
    let photosCopied: Int
    let photosMissing: Int
}

final class BackupManager {

    static let shared = BackupManager()

    private init() { }


    // MARK: - Create Complete Backup

    func createBackup(
        context: NSManagedObjectContext
    ) throws -> WaymarXBackup {

        // MARK: Fetch Users

        let userRequest: NSFetchRequest<CrumbUser> =
            CrumbUser.fetchRequest()

        let users = try context.fetch(userRequest)


        // MARK: Fetch Groups

        let groupRequest: NSFetchRequest<CrmGroup> =
            CrmGroup.fetchRequest()

        groupRequest.sortDescriptors = [
            NSSortDescriptor(
                key: "dateCreated",
                ascending: true
            )
        ]

        let groups = try context.fetch(groupRequest)


        // MARK: Fetch Breadcrumbs

        let breadcrumbRequest: NSFetchRequest<Breadcrumb> =
            Breadcrumb.fetchRequest()

        breadcrumbRequest.sortDescriptors = [
            NSSortDescriptor(
                key: "dateDropped",
                ascending: true
            )
        ]

        let breadcrumbs = try context.fetch(breadcrumbRequest)


        // MARK: Create Group Backup IDs

        /*
         Groups already have UUIDs, but older records could
         theoretically contain nil.

         We do NOT modify Core Data here.

         If a group has no UUID, we generate one only for
         this backup.
         */

        var groupBackupIDByObjectID:
            [NSManagedObjectID: UUID] = [:]

        for group in groups {

            let backupID = group.id ?? UUID()

            groupBackupIDByObjectID[group.objectID] = backupID
        }


        // MARK: Build Breadcrumb -> Group Relationship Map

        /*
         We preserve the real Core Data relationship by walking
         each group's breadcrumbs relationship.

         Breadcrumb ObjectID -> Group Backup UUID
         */

        var groupIDByBreadcrumbObjectID:
            [NSManagedObjectID: UUID] = [:]

        var groupNameByBreadcrumbObjectID:
            [NSManagedObjectID: String] = [:]

        for group in groups {

            guard let groupBackupID =
                    groupBackupIDByObjectID[group.objectID]
            else {
                continue
            }

            for breadcrumb in group.breadcrumbsArray {
                
                groupIDByBreadcrumbObjectID[
                    breadcrumb.objectID
                ] = groupBackupID
                
                if let groupName = group.groupName {
                    groupNameByBreadcrumbObjectID[
                        breadcrumb.objectID
                    ] = groupName
                }
            }
        }
        // MARK: Backup Users

        let userBackups: [WaymarXUserBackup] =
            users.map { user in

                WaymarXUserBackup(
                    username: user.username,
                    name: user.name,
                    address: user.address,
                    phoneNumber: user.phoneNumber,
                    homeLatitude: user.homeLatitude,
                    homeLongitude: user.homeLongitude,
                    profilePicture: user.profilePicture
                )
            }


        // MARK: Backup Groups

        let groupBackups: [WaymarXGroupBackup] =
            groups.compactMap { group in

                guard let backupID =
                        groupBackupIDByObjectID[group.objectID]
                else {
                    return nil
                }

                return WaymarXGroupBackup(
                    id: backupID,
                    dateCreated: group.dateCreated,
                    groupDescription: group.groupDescription,
                    groupName: group.groupName
                )
            }


        // MARK: Backup Breadcrumbs

        let breadcrumbBackups: [WaymarXBreadcrumbBackup] =
            breadcrumbs.map { breadcrumb in

                let relatedGroupID =
                    groupIDByBreadcrumbObjectID[
                        breadcrumb.objectID
                    ]

                return WaymarXBreadcrumbBackup(
                    backupID: UUID(),

                    dateDropped: breadcrumb.dateDropped,

                    latitude: breadcrumb.latitude,
                    longitude: breadcrumb.longitude,

                    name: breadcrumb.name,
                    note: breadcrumb.note,

                    isFavorite: breadcrumb.isFavorite,

                    streetAddress: breadcrumb.streetAddress,
                    city: breadcrumb.city,
                    state: breadcrumb.state,
                    zipCode: breadcrumb.zipCode,

                    photoURL: breadcrumb.photoURL,
                    groupID: relatedGroupID,
                    groupName: groupNameByBreadcrumbObjectID[breadcrumb.objectID],
                    
                    isWantToGo: breadcrumb.isWantToGo,
                    wantToGoDate: breadcrumb.wantToGoDate,
                    visitedDate: breadcrumb.visitedDate,
                    arrivalRadius: breadcrumb.arrivalRadius?.doubleValue,

                )
            }


        // MARK: App Version Information

        let appVersion =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "Unknown"

        let buildNumber =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String ?? "Unknown"


        // MARK: Complete Backup

        return WaymarXBackup(
            backupFormatVersion: 1,
            createdAt: Date(),

            appVersion: appVersion,
            buildNumber: buildNumber,

            users: userBackups,
            groups: groupBackups,
            breadcrumbs: breadcrumbBackups
        )
    }


    // MARK: - Encode Backup To JSON

    func encodeBackup(
        _ backup: WaymarXBackup
    ) throws -> Data {

        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(backup)
    }

    // MARK: - Create Backup File

    func createBackupFile(
        context: NSManagedObjectContext
    ) throws -> URL {

        // Create the backup from Core Data
        let backup = try createBackup(context: context)

        // Encode it as JSON
        let data = try encodeBackup(backup)

        // Build a readable timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let timestamp = formatter.string(from: Date())

        // Example:
        // WaymarX_Backup_2026-08-21_17-12-30.json
        let fileName =
            "WaymarX_Backup_\(timestamp).json"

        // Write into the app's temporary directory
        let backupFolder = try waymarXBackupFolder()

        let fileURL =
            backupFolder.appendingPathComponent(
                fileName
            )
        
        try data.write(
            to: fileURL,
            options: .atomic
        )

        return fileURL
    }

    func createBackupPackage(
        context: NSManagedObjectContext
    ) throws -> WaymarXBackupPackageResult {

        let fileManager = FileManager.default

        let backup = try createBackup(context: context)
        let backupData = try encodeBackup(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let timestamp = formatter.string(from: Date())

        let backupRoot =
            FileManager.default.temporaryDirectory
        
        let packageFolder =
            backupRoot.appendingPathComponent(
                "WaymarX_Backup_\(timestamp)",
                isDirectory: true
            )

        if fileManager.fileExists(atPath: packageFolder.path) {
            try fileManager.removeItem(at: packageFolder)
        }

        try fileManager.createDirectory(
            at: packageFolder,
            withIntermediateDirectories: true
        )

        let jsonURL =
            packageFolder.appendingPathComponent(
                "backup.json"
            )

        try backupData.write(
            to: jsonURL,
            options: .atomic
        )

        let photosFolder =
            packageFolder.appendingPathComponent(
                "photos",
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: photosFolder,
            withIntermediateDirectories: true
        )

        let photoNames: Set<String> =
            Set<String>(
                backup.breadcrumbs.compactMap { breadcrumb -> String? in

                    guard let photoURL =
                            breadcrumb.photoURL?
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ),
                          !photoURL.isEmpty
                    else {
                        return nil
                    }

                    return photoURL
                }
            )
        
        var photosCopied = 0
        var photosMissing = 0

        for photoName in photoNames {

            if let sourceURL =
                findPhotoFile(named: photoName) {

                let destinationURL =
                    photosFolder.appendingPathComponent(
                        photoName
                    )

                if !fileManager.fileExists(
                    atPath: destinationURL.path
                ) {
                    try fileManager.copyItem(
                        at: sourceURL,
                        to: destinationURL
                    )
                }

                photosCopied += 1

            } else {

                photosMissing += 1

                print(
                    "Backup Warning - Missing photo: \(photoName)"
                )
            }
        }

        return WaymarXBackupPackageResult(
            folderURL: packageFolder,
            pinCount: backup.breadcrumbs.count,
            groupCount: backup.groups.count,
            photoReferences: photoNames.count,
            photosCopied: photosCopied,
            photosMissing: photosMissing
        )
    }
    
    // MARK: - Create Shareable WaymarX Backup Archive

    func createBackupArchive(
        context: NSManagedObjectContext
    ) throws -> WaymarXArchiveResult {

        let fileManager = FileManager.default

        // First build our normal folder:
        //
        // WaymarX_Backup_xxx/
        //     backup.json
        //     photos/
        //
        let packageResult =
            try createBackupPackage(
                context: context
            )

        let packageFolder =
            packageResult.folderURL


        // MARK: Create final filename

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let timestamp =
            formatter.string(from: Date())

        let backupRoot =
            FileManager.default.temporaryDirectory
        
        let archiveURL =
            backupRoot.appendingPathComponent(
                "WaymarX_Backup_\(timestamp).waymarxbackup"
            )


        // Remove an existing file with the same name.
        if fileManager.fileExists(
            atPath: archiveURL.path
        ) {
            try fileManager.removeItem(
                at: archiveURL
            )
        }


        // MARK: AppleArchive Paths

        let sourcePath =
            FilePath(packageFolder.path)

        let destinationPath =
            FilePath(archiveURL.path)


        // MARK: Archive Fields

        /*
         These fields preserve the information needed to
         reconstruct the files and folders later.
         */

        guard let keySet =
                ArchiveHeader.FieldKeySet(
                    "TYP,PAT,DAT,SIZ,MOD"
                )
        else {
            throw NSError(
                domain: "WaymarXBackup",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Could not create the archive field key set."
                ]
            )
        }

        // MARK: Create Archive

        try ArchiveByteStream.withFileStream(
            path: destinationPath,
            mode: .writeOnly,
            options: [
                .create,
                .truncate
            ],
            permissions: [
                .ownerReadWrite
            ]
        ) { fileStream in

            try ArchiveByteStream.withCompressionStream(
                using: .lzfse,
                writingTo: fileStream
            ) { compressionStream in

                try ArchiveStream.withEncodeStream(
                    writingTo: compressionStream
                ) { encodeStream in

                    try encodeStream.writeDirectoryContents(
                        archiveFrom: sourcePath,
                        keySet: keySet
                    )
                }
            }
        }


        // MARK: Verify Final File

        guard fileManager.fileExists(
            atPath: archiveURL.path
        ) else {

            throw NSError(
                domain: "WaymarXBackup",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "The WaymarX backup archive was not created."
                ]
            )
        }


        // MARK: Remove Intermediate Folder

        /*
         We no longer need the folder after the single
         archive file has been created.
         */

        try? fileManager.removeItem(
            at: packageFolder
        )


        // MARK: Return Result

        return WaymarXArchiveResult(
            fileURL: archiveURL,

            pinCount: packageResult.pinCount,
            groupCount: packageResult.groupCount,

            photoReferences:
                packageResult.photoReferences,

            photosCopied:
                packageResult.photosCopied,

            photosMissing:
                packageResult.photosMissing
        )
    }
    // MARK: - Decode Backup From JSON

    func decodeBackup(
        from data: Data
    ) throws -> WaymarXBackup {

        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(
            WaymarXBackup.self,
            from: data
        )
    }
    // MARK: - WaymarX Backup Folder

    private func waymarXBackupFolder() throws -> URL {

        let fileManager = FileManager.default

        guard let documentsDirectory =
                fileManager.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first
        else {
            throw NSError(
                domain: "WaymarXBackup",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Could not locate the app Documents directory."
                ]
            )
        }

        let waymarXFolder =
            documentsDirectory.appendingPathComponent(
                "WaymarX",
                isDirectory: true
            )

        if !fileManager.fileExists(
            atPath: waymarXFolder.path
        ) {
            try fileManager.createDirectory(
                at: waymarXFolder,
                withIntermediateDirectories: true
            )
        }

        return waymarXFolder
    }
    private func findPhotoFile(
        named fileName: String
    ) -> URL? {

        let fileManager = FileManager.default

        guard let documentsDirectory =
                fileManager.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first
        else {
            return nil
        }

        let directURL =
            documentsDirectory.appendingPathComponent(
                fileName
            )

        if fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }

        guard let enumerator =
                fileManager.enumerator(
                    at: documentsDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
        else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == fileName {
                return fileURL
            }
        }

        return nil
    }
}
