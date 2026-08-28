//
//  ExportManager.swift
//  Iron Lady
//
//  Supports BOTH single-crum export and group export
//

import Foundation
import ZIPFoundation
import CoreData

struct ExportManager {

    // MARK: - Single Crumb Export (used by BreadcrumbDetailView)

    static func exportSingleCrumb(_ breadcrumb: Breadcrumb, completion: @escaping (URL?) -> Void) {
        let crumbExport = BreadcrumbExport(
            id: breadcrumb.id ?? UUID(),
            name: breadcrumb.name,
            city: breadcrumb.city,
            state: breadcrumb.state,
            streetAddress: breadcrumb.streetAddress,
            zipCode: breadcrumb.zipCode,
            dateDropped: breadcrumb.dateDropped,
            latitude: breadcrumb.latitude,
            longitude: breadcrumb.longitude,
            isFavorite: breadcrumb.isFavorite,
            note: breadcrumb.note,
            photoURL: breadcrumb.photoURL,
            isWantToGo: breadcrumb.isWantToGo,
            wantToGoDate: breadcrumb.wantToGoDate,
            visitedDate: breadcrumb.visitedDate,
            arrivalRadius: breadcrumb.arrivalRadius?.doubleValue
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(crumbExport)

            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // breadcrumb.json
            let jsonURL = tempDir.appendingPathComponent("breadcrumb.json")
            try jsonData.write(to: jsonURL)

            // photo (if present)
            if let photoFileName = breadcrumb.photoURL,
               let docs = getDocumentsDirectory() {
                let source = docs.appendingPathComponent(photoFileName)
                if FileManager.default.fileExists(atPath: source.path) {
                    let dest = tempDir.appendingPathComponent(photoFileName)
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: source, to: dest)
                }
            }

            let safeName = (breadcrumb.name?.isEmpty == false ? breadcrumb.name! : "Breadcrumb")
                .replacingOccurrences(of: "/", with: "-")

            let zipURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName)-\(UUID().uuidString).zip")

            try FileManager.default.zipItem(at: tempDir, to: zipURL)
            try? FileManager.default.removeItem(at: tempDir)

            completion(zipURL)
        } catch {
            print("exportSingleCrumb error: \(error)")
            completion(nil)
        }
    }

    // MARK: - Group Export (ZIP with group.json + images)

    static func exportGroup(_ group: CrmGroup, completion: @escaping (URL?) -> Void) {
        do {
            let crumbs = extractBreadcrumbs(from: group)

            let groupExport = CrmGroupExport(
                id: group.id ?? UUID(),
                groupName: group.groupName,
                groupDescription: group.groupDescription,
                dateCreated: group.dateCreated,
                breadcrumbs: crumbs.map { crumb in
                    BreadcrumbExport(
                        id: crumb.id ?? UUID(),
                        name: crumb.name,
                        city: crumb.city,
                        state: crumb.state,
                        streetAddress: crumb.streetAddress,
                        zipCode: crumb.zipCode,
                        dateDropped: crumb.dateDropped,
                        latitude: crumb.latitude,
                        longitude: crumb.longitude,
                        isFavorite: crumb.isFavorite,
                        note: crumb.note,
                        photoURL: crumb.photoURL,
                        isWantToGo: crumb.isWantToGo,
                        wantToGoDate: crumb.wantToGoDate,
                        visitedDate: crumb.visitedDate,
                        arrivalRadius: crumb.arrivalRadius?.doubleValue
                    )
                }
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(groupExport)

            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // group.json
            let jsonURL = tempDir.appendingPathComponent("group.json")
            try jsonData.write(to: jsonURL)

            // copy photos (dedupe by filename)
            let uniquePhotos = Array(Set(crumbs.compactMap { $0.photoURL }))
            if let docs = getDocumentsDirectory() {
                for fileName in uniquePhotos {
                    let source = docs.appendingPathComponent(fileName)
                    guard FileManager.default.fileExists(atPath: source.path) else { continue }
                    let dest = tempDir.appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: source, to: dest)
                }
            }

            let safeName = (group.groupName?.isEmpty == false ? group.groupName! : "Group")
                .replacingOccurrences(of: "/", with: "-")

            let zipURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName)-\(UUID().uuidString).zip")

            try FileManager.default.zipItem(at: tempDir, to: zipURL)
            try? FileManager.default.removeItem(at: tempDir)

            completion(zipURL)
        } catch {
            print("exportGroup error: \(error)")
            completion(nil)
        }
    }
    
    static func exportAllBreadcrumbs(
        _ breadcrumbs: [Breadcrumb],
        completion: @escaping (URL?) -> Void
    ) {

        // MARK: - Snapshot Core Data values FIRST
        //
        // Breadcrumb and CrmGroup are NSManagedObjects.
        // Read them here before doing file work on a background queue.

        let breadcrumbExports: [AllBreadcrumbExport] =
            breadcrumbs.map { crumb in

                AllBreadcrumbExport(
                    id: crumb.id ?? UUID(),
                    name: crumb.name,
                    city: crumb.city,
                    state: crumb.state,
                    streetAddress: crumb.streetAddress,
                    zipCode: crumb.zipCode,
                    dateDropped: crumb.dateDropped,
                    latitude: crumb.latitude,
                    longitude: crumb.longitude,
                    isFavorite: crumb.isFavorite,
                    note: crumb.note,
                    photoURL: crumb.photoURL,
                    groupID: crumb.crmGroup?.id,
                    groupName: crumb.crmGroup?.groupName,
                    groupDescription: crumb.crmGroup?.groupDescription,
                    groupDateCreated: crumb.crmGroup?.dateCreated,
                    isWantToGo: crumb.isWantToGo,
                    wantToGoDate: crumb.wantToGoDate,
                    visitedDate: crumb.visitedDate,
                    arrivalRadius: crumb.arrivalRadius?.doubleValue
                )
            }

        let uniquePhotos: [String] =
            Array(
                Set(
                    breadcrumbs.compactMap { breadcrumb in
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
            )


        // MARK: - Heavy file work OFF the UI thread

        DispatchQueue.global(qos: .userInitiated).async {

            let fileManager = FileManager.default

            do {

                // MARK: Encode JSON

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601

                let jsonData =
                    try encoder.encode(breadcrumbExports)


                // MARK: Create Temporary Package Folder

                let tempDir =
                    fileManager.temporaryDirectory
                        .appendingPathComponent(
                            "WaymarX-All-Pins-\(UUID().uuidString)",
                            isDirectory: true
                        )

                try fileManager.createDirectory(
                    at: tempDir,
                    withIntermediateDirectories: true
                )

                // Always clean up the temporary package folder.
                defer {
                    try? fileManager.removeItem(
                        at: tempDir
                    )
                }


                // MARK: Write breadcrumbs.json

                let jsonURL =
                    tempDir.appendingPathComponent(
                        "breadcrumbs.json"
                    )

                try jsonData.write(
                    to: jsonURL,
                    options: .atomic
                )


                // MARK: Copy Photos

                var totalPhotoBytes: Int64 = 0
                var photosFound = 0
                var photosMissing = 0

                if let documentsDirectory =
                        fileManager.urls(
                            for: .documentDirectory,
                            in: .userDomainMask
                        ).first {

                    for fileName in uniquePhotos {

                        let sourceURL =
                            documentsDirectory
                                .appendingPathComponent(
                                    fileName
                                )

                        guard fileManager.fileExists(
                            atPath: sourceURL.path
                        ) else {

                            photosMissing += 1

                            print(
                                "All Pins Export - Missing Photo:",
                                fileName
                            )

                            continue
                        }

                        // Count source photo size
                        if let attributes =
                                try? fileManager.attributesOfItem(
                                    atPath: sourceURL.path
                                ),
                           let size =
                                attributes[.size] as? NSNumber {

                            totalPhotoBytes +=
                                size.int64Value
                        }

                        photosFound += 1

                        let destinationURL =
                            tempDir.appendingPathComponent(
                                fileName
                            )

                        try fileManager.copyItem(
                            at: sourceURL,
                            to: destinationURL
                        )
                    }
                }


                // MARK: Diagnostic

                print("""

                ========================================
                ALL PINS EXPORT
                ========================================
                Pins: \(breadcrumbExports.count)
                Photo References: \(uniquePhotos.count)
                Photos Found: \(photosFound)
                Photos Missing: \(photosMissing)

                Photo Data MB:
                \(Double(totalPhotoBytes) / 1_048_576.0)

                Photo Data GB:
                \(Double(totalPhotoBytes) / 1_073_741_824.0)
                ========================================

                """)


                // MARK: Create ZIP

                let zipURL =
                    fileManager.temporaryDirectory
                        .appendingPathComponent(
                            "WaymarX-All-Pins-\(UUID().uuidString).zip"
                        )

                // Extremely defensive.
                if fileManager.fileExists(
                    atPath: zipURL.path
                ) {
                    try fileManager.removeItem(
                        at: zipURL
                    )
                }

                try fileManager.zipItem(
                    at: tempDir,
                    to: zipURL,
                    shouldKeepParent: false,
                    compressionMethod: .deflate
                )


                // MARK: Verify ZIP

                guard fileManager.fileExists(
                    atPath: zipURL.path
                ) else {

                    throw NSError(
                        domain: "WaymarXExport",
                        code: 20,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "The All Pins ZIP file was not created."
                        ]
                    )
                }

                let zipAttributes =
                    try fileManager.attributesOfItem(
                        atPath: zipURL.path
                    )

                let zipBytes =
                    (zipAttributes[.size] as? NSNumber)?
                        .int64Value ?? 0

                print("""

                ALL PINS ZIP CREATED

                ZIP MB:
                \(Double(zipBytes) / 1_048_576.0)

                ZIP GB:
                \(Double(zipBytes) / 1_073_741_824.0)

                File:
                \(zipURL.path)

                """)


                // MARK: Return to UI thread

                DispatchQueue.main.async {
                    completion(zipURL)
                }


            } catch {

                let nsError =
                    error as NSError

                print("""

                ========================================
                ALL PINS EXPORT FAILED
                ========================================
                Domain: \(nsError.domain)
                Code: \(nsError.code)
                Description: \(nsError.localizedDescription)
                Full Error: \(error)
                ========================================

                """)

                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    // MARK: - Helpers

    private static func extractBreadcrumbs(from group: CrmGroup) -> [Breadcrumb] {
        if let set = group.value(forKey: "breadcrumbs") as? Set<Breadcrumb> {
            return set.sorted { ($0.dateDropped ?? .distantPast) > ($1.dateDropped ?? .distantPast) }
        }
        if let set = group.value(forKey: "crumbs") as? Set<Breadcrumb> {
            return set.sorted { ($0.dateDropped ?? .distantPast) > ($1.dateDropped ?? .distantPast) }
        }
        return []
    }

    private static func getDocumentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    static func cleanupOldAllPinsExports() {

        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory

        do {
            let files = try fileManager.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil
            )

            for fileURL in files {

                let fileName =
                    fileURL.lastPathComponent

                if fileName.hasPrefix("WaymarX-All-Pins-"),
                   fileName.hasSuffix(".zip") {

                    print(
                        "Deleting old All Pins export:",
                        fileName
                    )

                    try? fileManager.removeItem(
                        at: fileURL
                    )
                }
            }

        } catch {
            print(
                "All Pins cleanup error:",
                error
            )
        }
    }
    
}
