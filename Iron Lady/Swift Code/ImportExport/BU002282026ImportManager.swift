//
//  ImportManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 3/19/25.
//
import Foundation
import ZIPFoundation
import CoreData

func findFile(named fileName: String, in directory: URL) -> URL? {
    let fileManager = FileManager.default
    guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
        return nil
    }
    for url in contents {
        if url.lastPathComponent == fileName {
            return url
        } else if url.hasDirectoryPath, let found = findFile(named: fileName, in: url) {
            return found
        }
    }
    return nil
}

struct ImportManager {

    static func importCrumbz(from url: URL, context: NSManagedObjectContext) throws {
        let fileManager = FileManager.default

        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        try fileManager.unzipItem(at: url, to: tempDirectory)

        guard let jsonFileURL = findFile(named: "breadcrumb.json", in: tempDirectory) else {
            throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "breadcrumb.json missing from ZIP file."])
        }

        let data = try Data(contentsOf: jsonFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedCrumb = try decoder.decode(BreadcrumbExport.self, from: data)

        try upsertBreadcrumb(importedCrumb, context: context, imageDirectory: tempDirectory, attachToGroup: nil)
        try context.save()
    }

    // MARK: - Group Import (NEW)

    static func importGroup(from url: URL, context: NSManagedObjectContext) throws {
        let fileManager = FileManager.default

        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        try fileManager.unzipItem(at: url, to: tempDirectory)

        guard let jsonFileURL = findFile(named: "group.json", in: tempDirectory) else {
            throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "group.json missing from ZIP file."])
        }

        let data = try Data(contentsOf: jsonFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedGroup = try decoder.decode(CrmGroupExport.self, from: data)

        let group = try upsertGroup(importedGroup, context: context)

        for crumb in importedGroup.breadcrumbs {
            try upsertBreadcrumb(crumb, context: context, imageDirectory: tempDirectory, attachToGroup: group)
        }

        try context.save()
    }

    private static func upsertGroup(_ groupData: CrmGroupExport, context: NSManagedObjectContext) throws -> CrmGroup {
        let fetch: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
        fetch.predicate = NSPredicate(format: "id == %@", groupData.id as CVarArg)

        let group = (try context.fetch(fetch).first) ?? CrmGroup(context: context)
        group.id = groupData.id
        group.groupName = groupData.groupName
        group.groupDescription = groupData.groupDescription
        group.dateCreated = groupData.dateCreated
        return group
    }

    private static func upsertBreadcrumb(
        _ breadcrumbData: BreadcrumbExport,
        context: NSManagedObjectContext,
        imageDirectory: URL?,
        attachToGroup group: CrmGroup?
    ) throws {
        let fetch: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
        fetch.predicate = NSPredicate(format: "id == %@", breadcrumbData.id as CVarArg)

        let breadcrumb = (try context.fetch(fetch).first) ?? Breadcrumb(context: context)

        breadcrumb.id = breadcrumbData.id
        breadcrumb.name = breadcrumbData.name
        breadcrumb.city = breadcrumbData.city
        breadcrumb.state = breadcrumbData.state
        breadcrumb.streetAddress = breadcrumbData.streetAddress
        breadcrumb.zipCode = breadcrumbData.zipCode
        breadcrumb.dateDropped = breadcrumbData.dateDropped
        breadcrumb.latitude = breadcrumbData.latitude
        breadcrumb.longitude = breadcrumbData.longitude
        breadcrumb.isFavorite = breadcrumbData.isFavorite
        breadcrumb.note = breadcrumbData.note

        if let photoFileName = breadcrumbData.photoURL,
           let imageDir = imageDirectory {

            var sourceImageURL = imageDir.appendingPathComponent(photoFileName)
            if !FileManager.default.fileExists(atPath: sourceImageURL.path),
               let foundURL = findFile(named: photoFileName, in: imageDir) {
                sourceImageURL = foundURL
            }

            if FileManager.default.fileExists(atPath: sourceImageURL.path),
               let destDir = getDocumentsDirectory() {
                let destinationURL = destDir.appendingPathComponent(photoFileName)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceImageURL, to: destinationURL)
                breadcrumb.photoURL = photoFileName
            }
        }

        if let group {
            attach(breadcrumb: breadcrumb, to: group)
        }
    }

    private static func attach(breadcrumb: Breadcrumb, to group: CrmGroup) {
        let bRels = breadcrumb.entity.relationshipsByName
        if bRels.keys.contains("crmGroup") {
            breadcrumb.setValue(group, forKey: "crmGroup")
        } else if bRels.keys.contains("group") {
            breadcrumb.setValue(group, forKey: "group")
        }

        let gRels = group.entity.relationshipsByName
        if gRels.keys.contains("breadcrumbs") {
            group.mutableSetValue(forKey: "breadcrumbs").add(breadcrumb)
        } else if gRels.keys.contains("crumbs") {
            group.mutableSetValue(forKey: "crumbs").add(breadcrumb)
        }
    }

    private static func getDocumentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}









// 022626 before group crumb export/impot modifications
//
//import Foundation
//import ZIPFoundation
//import CoreData
//
//// Helper function to search for a file recursively in a directory.
//func findFile(named fileName: String, in directory: URL) -> URL? {
//    let fileManager = FileManager.default
//    guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
//        return nil
//    }
//    for url in contents {
//        if url.lastPathComponent == fileName {
//            return url
//        } else if url.hasDirectoryPath, let found = findFile(named: fileName, in: url) {
//            return found
//        }
//    }
//    return nil
//}
//
//struct ImportManager {
//
//    static func importCrumbz(from url: URL, context: NSManagedObjectContext) throws {
//        let fileManager = FileManager.default
//
//        // Create a unique temporary directory to unzip the file
//        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
//        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
//
//        // Ensure temporary directory is removed after import
//        defer {
//            try? fileManager.removeItem(at: tempDirectory)
//        }
//
//        // Unzip the file into the temporary directory
//        try fileManager.unzipItem(at: url, to: tempDirectory)
//
//        // Instead of assuming the JSON file is directly at tempDirectory, search for it recursively
//        guard let jsonFileURL = findFile(named: "breadcrumb.json", in: tempDirectory) else {
//            throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "breadcrumb.json missing from ZIP file."])
//        }
//
//        let data = try Data(contentsOf: jsonFileURL)
//        let decoder = JSONDecoder()
//        decoder.dateDecodingStrategy = .iso8601
//
//        let importedCrumb = try decoder.decode(BreadcrumbExport.self, from: data)
//
//        // Import the breadcrumb data and optionally, the associated image
//        try importSingleCrumb(importedCrumb, context: context, imageDirectory: tempDirectory)
//    }
//
//    private static func importSingleCrumb(_ breadcrumbData: BreadcrumbExport, context: NSManagedObjectContext, imageDirectory: URL?) throws {
//        let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "id == %@", breadcrumbData.id as CVarArg)
//        
//        let breadcrumb = (try context.fetch(fetchRequest).first) ?? Breadcrumb(context: context)
//        
//        breadcrumb.id = breadcrumbData.id
//        breadcrumb.name = breadcrumbData.name
//        breadcrumb.city = breadcrumbData.city
//        breadcrumb.state = breadcrumbData.state
//        breadcrumb.streetAddress = breadcrumbData.streetAddress
//        breadcrumb.zipCode = breadcrumbData.zipCode
//        breadcrumb.dateDropped = breadcrumbData.dateDropped
//        breadcrumb.latitude = breadcrumbData.latitude
//        breadcrumb.longitude = breadcrumbData.longitude
//        breadcrumb.isFavorite = breadcrumbData.isFavorite
//        breadcrumb.note = breadcrumbData.note
//        
//        // Updated image extraction logic:
//        if let photoFileName = breadcrumbData.photoURL,
//           let imageDir = imageDirectory {
//            // Try expected location first
//            var sourceImageURL = imageDir.appendingPathComponent(photoFileName)
//            
//            // If not found there, search recursively using the helper function.
//            if !FileManager.default.fileExists(atPath: sourceImageURL.path),
//               let foundURL = findFile(named: photoFileName, in: imageDir) {
//                sourceImageURL = foundURL
//            }
//            
//            // Proceed only if the file exists.
//            if FileManager.default.fileExists(atPath: sourceImageURL.path),
//               let destDir = getDocumentsDirectory() {
//                let destinationURL = destDir.appendingPathComponent(photoFileName)
//                if FileManager.default.fileExists(atPath: destinationURL.path) {
//                    try FileManager.default.removeItem(at: destinationURL)
//                }
//                try FileManager.default.copyItem(at: sourceImageURL, to: destinationURL)
//                breadcrumb.photoURL = photoFileName
//            }
//        }
//        
//        try context.save()
//    }

//    private static func importSingleCrumb(_ breadcrumbData: BreadcrumbExport, context: NSManagedObjectContext, imageDirectory: URL?) throws {
//        let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "id == %@", breadcrumbData.id as CVarArg)
//
//        let breadcrumb = (try context.fetch(fetchRequest).first) ?? Breadcrumb(context: context)
//
//        breadcrumb.id = breadcrumbData.id
//        breadcrumb.name = breadcrumbData.name
//        breadcrumb.city = breadcrumbData.city
//        breadcrumb.state = breadcrumbData.state
//        breadcrumb.streetAddress = breadcrumbData.streetAddress
//        breadcrumb.zipCode = breadcrumbData.zipCode
//        breadcrumb.dateDropped = breadcrumbData.dateDropped
//        breadcrumb.latitude = breadcrumbData.latitude
//        breadcrumb.longitude = breadcrumbData.longitude
//        breadcrumb.isFavorite = breadcrumbData.isFavorite
//        breadcrumb.note = breadcrumbData.note
//
//        if let photoFileName = breadcrumbData.photoURL,
//           let sourceImageURL = imageDirectory?.appendingPathComponent(photoFileName),
//           FileManager.default.fileExists(atPath: sourceImageURL.path),
//           let destDir = getDocumentsDirectory() {
//
//            let destinationURL = destDir.appendingPathComponent(photoFileName)
//            if FileManager.default.fileExists(atPath: destinationURL.path) {
//                try FileManager.default.removeItem(at: destinationURL)
//            }
//            try FileManager.default.copyItem(at: sourceImageURL, to: destinationURL)
//            breadcrumb.photoURL = photoFileName
//        }
//
//        try context.save()
//    }

//    private static func getDocumentsDirectory() -> URL? {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
//    }
//}
