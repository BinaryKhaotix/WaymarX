//
//  GroupEditorView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/27/25.
//
import SwiftUI
import CoreData

struct GroupEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var groupName: String = ""
    @State private var groupDescription: String = ""

    @State private var showError = false
    @State private var errorMessage = ""

    var groupToEdit: CrmGroup? // Pass this in to edit an existing group

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    TextField("Description", text: $groupDescription)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(groupToEdit == nil ? "Add Group" : "Edit Group")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveGroup() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if let group = groupToEdit {
                groupName = group.groupName ?? ""
                groupDescription = group.groupDescription ?? ""
            }
        }
        .alert("Can't Save Group", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveGroup() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = groupDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Group Name can't be empty."
            showError = true
            return
        }

        // Prevent duplicates (case-insensitive), except if you're editing THIS same group
        let req: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "groupName ==[c] %@", trimmedName)

        do {
            let existing = try viewContext.fetch(req).first
            if let existing = existing, existing != groupToEdit {
                errorMessage = "A group named \"\(trimmedName)\" already exists."
                showError = true
                return
            }

            if let group = groupToEdit {
                // Edit existing group
                group.groupName = trimmedName
                group.groupDescription = trimmedDesc
            } else {
                // Create a new group
                let newGroup = CrmGroup(context: viewContext)
                newGroup.id = UUID()
                newGroup.dateCreated = Date()
                newGroup.groupName = trimmedName
                newGroup.groupDescription = trimmedDesc
            }

            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save group: \(error.localizedDescription)"
            showError = true
        }
    }
}



//import SwiftUI
//
//struct GroupEditorView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @Environment(\.dismiss) private var dismiss
//
//    @State private var groupName: String = ""
//    @State private var groupDescription: String = ""
//
//    var groupToEdit: CrmGroup? // Pass this in to edit an existing group
//
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("Group Details")) {
//                    TextField("Group Name", text: $groupName)
//                        .autocapitalization(.words)
//                        .disableAutocorrection(true)
//
//                    TextField("Description", text: $groupDescription)
//                        .autocapitalization(.sentences)
//                }
//            }
//            .navigationBarTitleDisplayMode(.inline)
//            .navigationTitle(groupToEdit == nil ? "Add Group" : "Edit Group")
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                    .foregroundColor(.red)
//                }
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Save") {
//                        saveGroup()
//                    }
//                    .foregroundColor(.white)
//                }
//            }
//        }
//        .onAppear {
//            if let group = groupToEdit {
//                groupName = group.groupName ?? ""
//                groupDescription = group.groupDescription ?? ""
//            }
//        }
//    }
//
//    private func saveGroup() {
//        if let group = groupToEdit {
//            // Edit existing group
//            group.groupName = groupName
//            group.groupDescription = groupDescription
//        } else {
//            // Create a new group
//            let newGroup = CrmGroup(context: viewContext)
//            newGroup.id = UUID()
//            newGroup.dateCreated = Date()
//            newGroup.groupName = groupName
//            newGroup.groupDescription = groupDescription
//        }
//
//        do {
//            try viewContext.save()
//            dismiss()
//        } catch {
//            print("Failed to save group: \(error)")
//        }
//    }
//}


//import SwiftUI
//
//struct GroupEditorView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @Environment(\.dismiss) private var dismiss
//
//    @State private var crmGroup?.groupName: String = ""
//    @State private var groupDescription: String = ""
//
//    var groupToEdit: CrmGroup? // Pass this in to edit an existing group
//
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("Group Details")) {
//                    TextField("Group Name", text: $crmGroup?.groupName)
//                        .autocapitalization(.words)
//                        .disableAutocorrection(true)
//
//                    TextField("Description", text: $groupDescription)
//                        .autocapitalization(.sentences)
//                }
//            }
//            .navigationTitle(groupToEdit == nil ? "Add Group" : "Edit Group")
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Save") {
//                        saveGroup()
//                    }
//                }
//            }
//        }
//        .onAppear {
//            if let group = groupToEdit {
//                crmGroup?.groupName = group.crmGroup?.groupName ?? ""
//                groupDescription = group.groupDescription ?? ""
//            }
//        }
//    }
//
//    private func saveGroup() {
//        if let group = groupToEdit {
//            // Edit existing group
//            group.crmGroup?.groupName = crmGroup?.groupName
//            group.groupDescription = groupDescription
//        } else {
//            // Create a new group
//            let newGroup = CrmGroup(context: viewContext)
//            newGroup.id = UUID()
//            newGroup.dateCreated = Date()
//            newGroup.crmGroup?.groupName = crmGroup?.groupName
//            newGroup.groupDescription = groupDescription
//        }
//
//        do {
//            try viewContext.save()
//            dismiss()
//        } catch {
//            print("Failed to save group: \(error)")
//        }
//    }
//}
