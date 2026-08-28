import Foundation
import ZIPFoundation
import CoreData


func findFile(named fileName: String, in directory: URL) -> URL? {
    let fileManager = FileManager.default

    guard let contents = try? fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
    ) else {
        return nil
    }

    for url in contents {
        if url.lastPathComponent == fileName {
            return url
        }

        if url.hasDirectoryPath,
           let found = findFile(named: fileName, in: url) {
            return found
        }
    }

    return nil
}

struct ImportResult {
    let pinsCreated: Int
    let pinsUpdated: Int
    let groupsCreated: Int
    let groupsUpdated: Int
}

struct ImportManager {
    private static func withImportRollback<T>(
        context: NSManagedObjectContext,
        operation: () throws -> T
    ) throws -> T {

        do {
            return try operation()

        } catch {
            context.rollback()
            throw error
        }
    }
    
    @discardableResult
    static func importCrumbz(
        from url: URL,
        context: NSManagedObjectContext
    ) throws -> ImportResult {
        
        return try withImportRollback(
            context: context
        ) {
            
            let fileManager = FileManager.default
            
            let tempDir =
            fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            
            try fileManager.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            
            defer {
                try? fileManager.removeItem(at: tempDir)
            }
            
            try fileManager.unzipItem(
                at: url,
                to: tempDir
            )
            
            guard let jsonURL =
                    findFile(
                        named: "breadcrumb.json",
                        in: tempDir
                    )
            else {
                throw NSError(
                    domain: "ImportError",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "breadcrumb.json missing from ZIP file."
                    ]
                )
            }
            
            let data =
            try Data(contentsOf: jsonURL)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let crumbData =
            try decoder.decode(
                BreadcrumbExport.self,
                from: data
            )
            
            let fetch:
            NSFetchRequest<Breadcrumb> =
            Breadcrumb.fetchRequest()
            
            fetch.predicate =
            NSPredicate(
                format: "id == %@",
                crumbData.id as CVarArg
            )
            
            let existingBreadcrumb =
            try context.fetch(fetch).first
            
            let breadcrumb: Breadcrumb
            
            let pinsCreated: Int
            let pinsUpdated: Int
            
            if let existingBreadcrumb {
                breadcrumb = existingBreadcrumb
                pinsCreated = 0
                pinsUpdated = 1
            } else {
                breadcrumb = Breadcrumb(context: context)
                pinsCreated = 1
                pinsUpdated = 0
            }
            
            breadcrumb.id = crumbData.id
            breadcrumb.name = crumbData.name
            breadcrumb.city = crumbData.city
            breadcrumb.state = crumbData.state
            breadcrumb.streetAddress = crumbData.streetAddress
            breadcrumb.zipCode = crumbData.zipCode
            breadcrumb.dateDropped = crumbData.dateDropped
            breadcrumb.latitude = crumbData.latitude
            breadcrumb.longitude = crumbData.longitude
            breadcrumb.isFavorite = crumbData.isFavorite
            breadcrumb.note = crumbData.note
            breadcrumb.photoURL = crumbData.photoURL
            
            if let photoFileName = crumbData.photoURL,
               !photoFileName.isEmpty {
                
                if let sourceURL =
                    findFile(
                        named: photoFileName,
                        in: tempDir
                    ),
                   let documentsDirectory =
                    fileManager.urls(
                        for: .documentDirectory,
                        in: .userDomainMask
                    ).first {
                    
                    let destinationURL =
                    documentsDirectory
                        .appendingPathComponent(
                            photoFileName
                        )
                    
                    if fileManager.fileExists(
                        atPath: destinationURL.path
                    ) {
                        try? fileManager.removeItem(
                            at: destinationURL
                        )
                    }
                    
                    try fileManager.copyItem(
                        at: sourceURL,
                        to: destinationURL
                    )
                }
            }
            
            try context.save()
            
            return ImportResult(
                pinsCreated: pinsCreated,
                pinsUpdated: pinsUpdated,
                groupsCreated: 0,
                groupsUpdated: 0
            )
        }
    }
    
    @discardableResult
    static func importGroup(
        from url: URL,
        context: NSManagedObjectContext
    ) throws -> ImportResult {
        
        return try withImportRollback(
            context: context
        ) {
            
            let fileManager = FileManager.default
            
            let tempDir =
            fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            
            try fileManager.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            
            defer {
                try? fileManager.removeItem(at: tempDir)
            }
            
            // Unzip export package
            try fileManager.unzipItem(
                at: url,
                to: tempDir
            )
            
            // Find group.json
            guard let jsonURL =
                    findFile(
                        named: "group.json",
                        in: tempDir
                    )
            else {
                throw NSError(
                    domain: "ImportError",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "group.json is missing from the ZIP file."
                    ]
                )
            }
            
            // Decode group export
            let data =
            try Data(contentsOf: jsonURL)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let groupData =
            try decoder.decode(
                CrmGroupExport.self,
                from: data
            )
            
            var pinsCreated = 0
            var pinsUpdated = 0
            var groupsCreated = 0
            var groupsUpdated = 0
            
            // MARK: - Find or create Group
            
            let groupFetch:
            NSFetchRequest<CrmGroup> =
            CrmGroup.fetchRequest()
            
            groupFetch.predicate =
            NSPredicate(
                format: "id == %@",
                groupData.id as CVarArg
            )
            
            let existingGroup =
            try context.fetch(groupFetch).first
            
            let group: CrmGroup
            
            if let existingGroup {
                group = existingGroup
                groupsUpdated += 1
            } else {
                group = CrmGroup(context: context)
                groupsCreated += 1
            }
            
            group.id = groupData.id
            group.groupName = groupData.groupName
            group.groupDescription = groupData.groupDescription
            group.dateCreated = groupData.dateCreated
            
            
            // MARK: - Import Breadcrumbs
            
            for crumbData in groupData.breadcrumbs {
                
                let crumbFetch:
                NSFetchRequest<Breadcrumb> =
                Breadcrumb.fetchRequest()
                
                crumbFetch.predicate =
                NSPredicate(
                    format: "id == %@",
                    crumbData.id as CVarArg
                )
                
                let existingBreadcrumb =
                try context.fetch(crumbFetch).first
                
                let breadcrumb: Breadcrumb
                
                if let existingBreadcrumb {
                    breadcrumb = existingBreadcrumb
                    pinsUpdated += 1
                } else {
                    breadcrumb = Breadcrumb(context: context)
                    pinsCreated += 1
                }
                
                breadcrumb.id =
                crumbData.id
                
                breadcrumb.name =
                crumbData.name
                
                breadcrumb.city =
                crumbData.city
                
                breadcrumb.state =
                crumbData.state
                
                breadcrumb.streetAddress =
                crumbData.streetAddress
                
                breadcrumb.zipCode =
                crumbData.zipCode
                
                breadcrumb.dateDropped =
                crumbData.dateDropped
                
                breadcrumb.latitude =
                crumbData.latitude
                
                breadcrumb.longitude =
                crumbData.longitude
                
                breadcrumb.isFavorite =
                crumbData.isFavorite
                
                breadcrumb.note =
                crumbData.note
                
                breadcrumb.photoURL =
                crumbData.photoURL
                
                
                // MARK: Restore group relationship
                
                breadcrumb.crmGroup =
                group
                
                
                // MARK: Restore Photo
                
                if let photoFileName =
                    crumbData.photoURL,
                   !photoFileName.isEmpty {
                    
                    if let sourceURL =
                        findFile(
                            named: photoFileName,
                            in: tempDir
                        ),
                       let documentsDirectory =
                        fileManager.urls(
                            for: .documentDirectory,
                            in: .userDomainMask
                        ).first {
                        
                        let destinationURL =
                        documentsDirectory
                            .appendingPathComponent(
                                photoFileName
                            )
                        
                        if fileManager.fileExists(
                            atPath: destinationURL.path
                        ) {
                            try? fileManager.removeItem(
                                at: destinationURL
                            )
                        }
                        
                        try fileManager.copyItem(
                            at: sourceURL,
                            to: destinationURL
                        )
                    }
                }
            }
            
            
            
            // MARK: - Save Everything
            
            try context.save()
            return ImportResult(
                pinsCreated: pinsCreated,
                pinsUpdated: pinsUpdated,
                groupsCreated: groupsCreated,
                groupsUpdated: groupsUpdated
            )
        }
    }
    
    @discardableResult
    static func importAllBreadcrumbs(
        from url: URL,
        context: NSManagedObjectContext
    ) throws -> ImportResult {
        
        return try withImportRollback(
            context: context
        ) {
            
            let fileManager = FileManager.default
            
            let tempDir =
            fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            
            try fileManager.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            
            defer {
                try? fileManager.removeItem(at: tempDir)
            }
            
            // Unzip package
            try fileManager.unzipItem(
                at: url,
                to: tempDir
            )
            
            // Find breadcrumbs.json
            guard let jsonURL =
                    findFile(
                        named: "breadcrumbs.json",
                        in: tempDir
                    )
            else {
                throw NSError(
                    domain: "ImportError",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "breadcrumbs.json is missing from the ZIP file."
                    ]
                )
            }
            
            let data =
            try Data(contentsOf: jsonURL)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let breadcrumbData =
            try decoder.decode(
                [AllBreadcrumbExport].self,
                from: data
            )
            
            var pinsCreated = 0
            var pinsUpdated = 0
            
            var groupsCreated = 0
            var groupsUpdated = 0
            
            var processedGroupIDs = Set<UUID>()
            
            for crumbData in breadcrumbData {
                
                // MARK: Find or Create Breadcrumb
                
                let crumbFetch:
                NSFetchRequest<Breadcrumb> =
                Breadcrumb.fetchRequest()
                
                crumbFetch.predicate =
                NSPredicate(
                    format: "id == %@",
                    crumbData.id as CVarArg
                )
                
                let existingBreadcrumb =
                try context.fetch(crumbFetch).first
                
                let breadcrumb: Breadcrumb
                
                if let existingBreadcrumb {
                    breadcrumb = existingBreadcrumb
                    pinsUpdated += 1
                } else {
                    breadcrumb = Breadcrumb(context: context)
                    pinsCreated += 1
                }
                
                // MARK: Restore Breadcrumb Data
                
                breadcrumb.id =
                crumbData.id
                
                breadcrumb.name =
                crumbData.name
                
                breadcrumb.city =
                crumbData.city
                
                breadcrumb.state =
                crumbData.state
                
                breadcrumb.streetAddress =
                crumbData.streetAddress
                
                breadcrumb.zipCode =
                crumbData.zipCode
                
                breadcrumb.dateDropped =
                crumbData.dateDropped
                
                breadcrumb.latitude =
                crumbData.latitude
                
                breadcrumb.longitude =
                crumbData.longitude
                
                breadcrumb.isFavorite =
                crumbData.isFavorite
                
                breadcrumb.note =
                crumbData.note
                
                breadcrumb.photoURL =
                crumbData.photoURL
                
                
                // MARK: Restore Group Relationship
                
                if let groupID = crumbData.groupID {
                    
                    let groupFetch:
                    NSFetchRequest<CrmGroup> =
                    CrmGroup.fetchRequest()
                    
                    groupFetch.predicate =
                    NSPredicate(
                        format: "id == %@",
                        groupID as CVarArg
                    )
                    
                    let existingGroup =
                    try context.fetch(groupFetch).first
                    
                    let group: CrmGroup
                    
                    if let existingGroup {
                        
                        group = existingGroup
                        
                        if !processedGroupIDs.contains(groupID) {
                            groupsUpdated += 1
                        }
                        
                    } else {
                        
                        group = CrmGroup(context: context)
                        
                        if !processedGroupIDs.contains(groupID) {
                            groupsCreated += 1
                        }
                    }
                    
                    processedGroupIDs.insert(groupID)
                    
                    group.id =
                    groupID
                    
                    group.groupName =
                    crumbData.groupName
                    
                    group.groupDescription =
                    crumbData.groupDescription
                    
                    group.dateCreated =
                    crumbData.groupDateCreated
                    
                    breadcrumb.crmGroup =
                    group
                    
                } else {
                    
                    breadcrumb.crmGroup =
                    nil
                }
                
                
                // MARK: Restore Photo
                
                if let photoFileName =
                    crumbData.photoURL,
                   !photoFileName.isEmpty {
                    
                    if let sourceURL =
                        findFile(
                            named: photoFileName,
                            in: tempDir
                        ),
                       let documentsDirectory =
                        fileManager.urls(
                            for: .documentDirectory,
                            in: .userDomainMask
                        ).first {
                        
                        let destinationURL =
                        documentsDirectory
                            .appendingPathComponent(
                                photoFileName
                            )
                        
                        if fileManager.fileExists(
                            atPath: destinationURL.path
                        ) {
                            try? fileManager.removeItem(
                                at: destinationURL
                            )
                        }
                        
                        try fileManager.copyItem(
                            at: sourceURL,
                            to: destinationURL
                        )
                    }
                }
            }
            
            // MARK: Save
            
            try context.save()
            
            return ImportResult(
                pinsCreated: pinsCreated,
                pinsUpdated: pinsUpdated,
                groupsCreated: groupsCreated,
                groupsUpdated: groupsUpdated
            )
        }
    }
}
