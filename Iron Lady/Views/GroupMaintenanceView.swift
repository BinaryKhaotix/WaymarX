//
//  GroupMaintenanceView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/22/26.
//

import SwiftUI
import CoreData

struct GroupMaintenanceView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var logText: String = ""
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Group Maintenance")
                .font(.title2)
                .bold()

            Button {
                run()
            } label: {
                Text(isRunning ? "Running..." : "Fix & Merge Duplicate Groups")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunning ? Color.gray.opacity(0.3) : Color("Dark Blue"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isRunning)

            ScrollView {
                Text(logText.isEmpty ? "Log will appear here." : logText)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .navigationTitle("Groups")
    }

    private func run() {
        isRunning = true
        logText = ""

        do {
            let report = try GroupMaintenance.run(using: viewContext)
            logText = report
        } catch {
            logText = "ERROR: \(error.localizedDescription)"
        }

        isRunning = false
    }
}

enum GroupMaintenance {
    // MARK: - Public entry point
    static func run(using context: NSManagedObjectContext) throws -> String {
        // 1) Fetch all groups
        let groupsReq: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
        groupsReq.sortDescriptors = [
            NSSortDescriptor(key: "groupName", ascending: true),
            NSSortDescriptor(key: "dateCreated", ascending: true)
        ]
        let allGroups = try context.fetch(groupsReq)

        // 2) Build canonical map using HARD normalized keys
        var canonicalByKey: [String: CrmGroup] = [:]
        var duplicatesToMerge: [(dup: CrmGroup, keep: CrmGroup)] = []

        // Track how many groups have weird/empty names
        var emptyOrInvalidNames: [CrmGroup] = []

        for g in allGroups {
            let raw = g.groupName ?? ""
            let key = normalizeKey(raw)

            if key.isEmpty {
                emptyOrInvalidNames.append(g)
                continue
            }

            if let keep = canonicalByKey[key] {
                duplicatesToMerge.append((dup: g, keep: keep))
            } else {
                canonicalByKey[key] = g

                // Also standardize the display name stored on the canonical group
                let display = cleanDisplayName(raw)
                if display.isEmpty {
                    emptyOrInvalidNames.append(g)
                } else if display != raw {
                    g.groupName = display
                }
            }
        }

        // 3) Merge duplicates by reassigning Breadcrumb.crmGroup
        var reassignedBreadcrumbs = 0
        for pair in duplicatesToMerge {
            // Fetch crumbs that reference the duplicate group
            let bReq: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
            bReq.predicate = NSPredicate(format: "crmGroup == %@", pair.dup)

            let crumbs = try context.fetch(bReq)
            for b in crumbs {
                b.crmGroup = pair.keep
            }
            reassignedBreadcrumbs += crumbs.count

            // Delete the duplicate group
            context.delete(pair.dup)
        }

        // 4) Optional: fix "empty name" groups by deleting them if they have no breadcrumbs
        // (This prevents ghost groups cluttering pickers.)
        // If you'd rather KEEP them, comment this block out.
        var deletedEmptyGroups = 0
        for g in emptyOrInvalidNames {
            // If any breadcrumbs point to this group, we keep it (safer)
            let bReq: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
            bReq.fetchLimit = 1
            bReq.predicate = NSPredicate(format: "crmGroup == %@", g)
            let hasAnyBreadcrumb = (try context.count(for: bReq)) > 0

            if !hasAnyBreadcrumb {
                context.delete(g)
                deletedEmptyGroups += 1
            }
        }

        // 5) Save changes
        if context.hasChanges {
            try context.save()
        }

        // 6) Post-check: count remaining duplicates by normalized key
        let postReq: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
        postReq.sortDescriptors = [NSSortDescriptor(key: "groupName", ascending: true)]
        let postGroups = try context.fetch(postReq)

        let remainingDuplicates = findDuplicateSummary(groups: postGroups)

        // 7) Report
        var report = ""
        report += "Groups before: \(allGroups.count)\n"
        report += "Duplicates merged: \(duplicatesToMerge.count)\n"
        report += "Breadcrumbs reassigned: \(reassignedBreadcrumbs)\n"
        report += "Empty/invalid-name groups deleted: \(deletedEmptyGroups)\n"
        report += "Groups after: \(postGroups.count)\n"

        if remainingDuplicates.isEmpty {
            report += "\n✅ No remaining duplicate group names (by hard normalization).\n"
        } else {
            report += "\n⚠️ Remaining duplicates detected (these are truly different even after normalization):\n"
            report += remainingDuplicates
        }

        return report
    }

    // MARK: - Normalization

    /// A key used for grouping duplicates. This is intentionally aggressive.
    private static func normalizeKey(_ s: String) -> String {
        var x = s

        // Trim ends
        x = x.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize unicode (so visually-identical strings collapse)
        x = x.precomposedStringWithCanonicalMapping

        // Convert NBSP to space
        x = x.replacingOccurrences(of: "\u{00A0}", with: " ")

        // Remove zero-width junk that ruins equality
        let zeroWidth = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"]
        for z in zeroWidth {
            x = x.replacingOccurrences(of: z, with: "")
        }

        // Collapse internal whitespace
        x = x.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Case + diacritic fold (stronger than lowercased)
        x = x.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return x
    }

    /// A “pretty” name to store in Core Data (trimmed + single spaced, original casing preserved).
    private static func cleanDisplayName(_ s: String) -> String {
        var x = s.trimmingCharacters(in: .whitespacesAndNewlines)
        x = x.precomposedStringWithCanonicalMapping
        x = x.replacingOccurrences(of: "\u{00A0}", with: " ")
        let zeroWidth = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"]
        for z in zeroWidth { x = x.replacingOccurrences(of: z, with: "") }
        x = x.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return x
    }

    // MARK: - Post-check helpers

    private static func findDuplicateSummary(groups: [CrmGroup]) -> String {
        var buckets: [String: [CrmGroup]] = [:]

        for g in groups {
            let raw = g.groupName ?? ""
            let key = normalizeKey(raw)
            if key.isEmpty { continue }
            buckets[key, default: []].append(g)
        }

        let dups = buckets
            .filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }

        guard !dups.isEmpty else { return "" }

        var lines: [String] = []
        for (key, list) in dups {
            let names = list.map { ($0.groupName ?? "nil") }
            lines.append("• Key='\(key)' count=\(list.count) names=\(names)")
        }
        return lines.joined(separator: "\n")
    }
}
