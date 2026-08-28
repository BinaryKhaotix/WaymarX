//
//  ExportManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 3/19/25.
//
import Foundation
import ZIPFoundation
import UIKit
import CoreData

struct ExportManager {

    // MARK: - Single Crumb Export (kept behavior)

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
            photoURL: breadcrumb.photoURL
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(crumbExport)

            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

            let jsonURL = tempDirectory.appendingPathComponent("breadcrumb.json")
            try jsonData.write(to: jsonURL)

            if let photoFileName = breadcrumb.photoURL,
               let imageURL = getDocumentsDirectory()?.appendingPathComponent(photoFileName),
               FileManager.default.fileExists(atPath: imageURL.path) {

                let destinationURL = tempDirectory.appendingPathComponent(photoFileName)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: imageURL, to: destinationURL)
            }

            let zipURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(breadcrumb.name ?? "Breadcrumb")-\(UUID().uuidString).zip")

            try FileManager.default.zipItem(at: tempDirectory, to: zipURL)
            try FileManager.default.removeItem(at: tempDirectory)

            completion(zipURL)
        } catch {
            print("Export error: \(error)")
            completion(nil)
        }
    }

    // MARK: - Group Export (NEW)

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
                        photoURL: crumb.photoURL
                    )
                }
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(groupExport)

            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

            let jsonURL = tempDirectory.appendingPathComponent("group.json")
            try jsonData.write(to: jsonURL)

            // Copy photos (dedupe by filename)
            let uniquePhotoFiles = Array(Set(crumbs.compactMap { $0.photoURL }))
            for fileName in uniquePhotoFiles {
                guard let source = getDocumentsDirectory()?.appendingPathComponent(fileName),
                      FileManager.default.fileExists(atPath: source.path) else { continue }

                let dest = tempDirectory.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try? FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: source, to: dest)
            }

            let safeName = (group.groupName?.isEmpty == false ? group.groupName! : "Group")
                .replacingOccurrences(of: "/", with: "-")

            let zipURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName)-\(UUID().uuidString).zip")

            try FileManager.default.zipItem(at: tempDirectory, to: zipURL)
            try FileManager.default.removeItem(at: tempDirectory)

            completion(zipURL)
        } catch {
            print("Group export error: \(error)")
            completion(nil)
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
}








//022626 before Group Crumb Export/import Modifications
//
//import Foundation
//import ZIPFoundation
//import UIKit
//
//struct ExportManager {
//
//    static func exportSingleCrumb(_ breadcrumb: Breadcrumb, completion: @escaping (URL?) -> Void) {
//        let crumbExport = BreadcrumbExport(
//            id: breadcrumb.id ?? UUID(),
//            name: breadcrumb.name,
//            city: breadcrumb.city,
//            state: breadcrumb.state,
//            streetAddress: breadcrumb.streetAddress,
//            zipCode: breadcrumb.zipCode,
//            dateDropped: breadcrumb.dateDropped,
//            latitude: breadcrumb.latitude,
//            longitude: breadcrumb.longitude,
//            isFavorite: breadcrumb.isFavorite,
//            note: breadcrumb.note,
//            photoURL: breadcrumb.photoURL
//        )
//
//        do {
//            let encoder = JSONEncoder()
//            encoder.outputFormatting = .prettyPrinted
//            encoder.dateEncodingStrategy = .iso8601
//            let jsonData = try encoder.encode(crumbExport)
//
//            // Temporary directory for export
//            let tempDirectory = FileManager.default.temporaryDirectory
//                .appendingPathComponent(UUID().uuidString)
//            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
//
//            // Write JSON
//            let jsonURL = tempDirectory.appendingPathComponent("breadcrumb.json")
//            try jsonData.write(to: jsonURL)
//
//            // Check and include image if exists
//            if let photoFileName = breadcrumb.photoURL,
//               let imageURL = getDocumentsDirectory()?.appendingPathComponent(photoFileName),
//               FileManager.default.fileExists(atPath: imageURL.path) {
//
//                let destinationURL = tempDirectory.appendingPathComponent(photoFileName)
//                try FileManager.default.copyItem(at: imageURL, to: destinationURL)
//            }
//
//            // ZIP the directory
//            let zipURL = FileManager.default.temporaryDirectory
//                .appendingPathComponent("\(breadcrumb.name ?? "Breadcrumb")-\(UUID().uuidString).zip")
//
//            try FileManager.default.zipItem(at: tempDirectory, to: zipURL)
//
//            // Cleanup temp folder
//            try FileManager.default.removeItem(at: tempDirectory)
//
//            completion(zipURL)
//        } catch {
//            print("Export error: \(error)")
//            completion(nil)
//        }
//    }
//
//    private static func getDocumentsDirectory() -> URL? {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
//    }
//}
