//
//  MergeDupGroups.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/22/26.
//
import CoreData
import SwiftUI



private func mergeDuplicateGroups(using context: NSManagedObjectContext) {
    let req: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
    req.sortDescriptors = [
        NSSortDescriptor(key: "groupName", ascending: true),
        NSSortDescriptor(key: "dateCreated", ascending: true)
    ]

    do {
        let all = try viewContext.fetch(req)

        var canonicalByKey: [String: CrmGroup] = [:]
        var duplicates: [CrmGroup] = []

        for g in all {
            // Normalize name hard (trim + lowercase)
            let name = (g.groupName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.lowercased()
            if key.isEmpty { continue }

            if let canonical = canonicalByKey[key] {
                // Reassign breadcrumbs from duplicate -> canonical
                if let crumbs = g.breadcrumbs as? Set<Breadcrumb> {
                    for b in crumbs {
                        b.crmGroup = canonical
                    }
                }
                duplicates.append(g)
            } else {
                canonicalByKey[key] = g
            }
        }

        // Delete duplicates
        for d in duplicates {
            viewContext.delete(d)
        }

        if viewContext.hasChanges {
            try viewContext.save()
        }

        print("Merged \(duplicates.count) duplicate groups.")
    } catch {
        print("Failed merging duplicates: \(error.localizedDescription)")
    }
}

