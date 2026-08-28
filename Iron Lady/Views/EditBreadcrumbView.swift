//
//  EditBreadcrumbView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//
import SwiftUI
import CoreData

struct EditBreadcrumbView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationModel: NavigationModel

    @ObservedObject var breadcrumb: Breadcrumb

    // Fetch existing groups for selection
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.groupName, ascending: true)],
        animation: .default
    ) private var groups: FetchedResults<CrmGroup>

    // This MUST live in the parent view (stable owner of the sheet)
    @State private var groupToEdit: CrmGroup? = nil

    @State private var updatedName: String
    @State private var updatedNote: String

    // Group selection
    @State private var selectedGroup: CrmGroup?
    @State private var isAddingNewGroup: Bool = false
    @State private var newGroupName: String = ""

    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false

    init(breadcrumb: Breadcrumb) {
        self.breadcrumb = breadcrumb
        _updatedName = State(initialValue: breadcrumb.name ?? "")
        _updatedNote = State(initialValue: breadcrumb.note ?? "")
        _selectedGroup = State(initialValue: breadcrumb.crmGroup)
    }

    var body: some View {
        VStack {
            // Header
            Text("Edit your Pin details!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()

            ScrollView {
                VStack(spacing: 20) {
                    // Input Section
                    EditBreadcrumbInputSection(
                        breadcrumbName: $updatedName,
                        note: $updatedNote,
                        groups: groups,
                        selectedGroup: $selectedGroup,
                        isAddingNewGroup: $isAddingNewGroup,
                        newGroupName: $newGroupName,
                        onEditSelectedGroup: {
                            // Only set if non-nil
                            if let g = selectedGroup {
                                groupToEdit = g
                            }
                        }
                    )

                    // Image Section (unchanged)
                    EditBreadcrumbImageSection(
                        breadcrumb: breadcrumb,
                        selectedImage: $selectedImage,
                        showCamera: $showCamera,
                        showImagePicker: $showImagePicker
                    )
                }
                .padding(.horizontal)
            }

            // Save Button
            Button(action: saveChanges) {
                Text("Save Changes")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("Dark Orange"))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding(.horizontal)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Edit Pin")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { navigationModel.pop() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                        Text("Back")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage) { _ in }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $selectedImage) { image in
                if let image = image {
                    _ = saveImageLocally(image)
                }
            }
        }
        .sheet(item: $groupToEdit) { group in
            GroupEditorView(groupToEdit: group)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Save Changes Logic
    private func saveChanges() {
        breadcrumb.name = updatedName
        breadcrumb.note = updatedNote

        if let selectedGroup = selectedGroup {
            breadcrumb.crmGroup = selectedGroup
        } else {
            let trimmedNewName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)

            if isAddingNewGroup, !trimmedNewName.isEmpty {
                let req: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
                req.fetchLimit = 1
                req.predicate = NSPredicate(format: "groupName ==[c] %@", trimmedNewName)

                do {
                    if let existing = try viewContext.fetch(req).first {
                        breadcrumb.crmGroup = existing
                    } else {
                        let newGroup = CrmGroup(context: viewContext)
                        newGroup.id = UUID()
                        newGroup.dateCreated = Date()
                        newGroup.groupName = trimmedNewName
                        newGroup.groupDescription = "Created from Pin"
                        breadcrumb.crmGroup = newGroup
                    }
                } catch {
                    print("Error fetching/creating CrmGroup: \(error.localizedDescription)")
                }
            } else {
                breadcrumb.crmGroup = nil
            }
        }

        if let image = selectedImage {
            breadcrumb.photoURL = saveImageLocally(image)
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save changes: \(error.localizedDescription)")
        }
    }

    private func saveImageLocally(_ image: UIImage) -> String {
        let fileName = UUID().uuidString + ".jpg"
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            try? data.write(to: url)
            return fileName
        }
        return ""
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct EditBreadcrumbImageSection: View {
    let breadcrumb: Breadcrumb
    @Binding var selectedImage: UIImage?
    @Binding var showCamera: Bool
    @Binding var showImagePicker: Bool

    var body: some View {
        Section {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding(.bottom, 10)
                } else if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding(.bottom, 10)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .overlay(
                            Text("No Image Available")
                                .font(.headline)
                                .foregroundColor(.gray)
                        )
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                }
            }

            HStack(spacing: 40) {
                Button(action: { showCamera = true }) {
                    Image(systemName: "camera")
                        .font(.largeTitle)
                        .foregroundColor(Color("Dark Blue"))
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }

                Button(action: { showImagePicker = true }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(Color("Dark Blue"))
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }

    private func loadImage(from fileName: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct EditBreadcrumbInputSection: View {
    @Binding var breadcrumbName: String
    @Binding var note: String

    let groups: FetchedResults<CrmGroup>
    @Binding var selectedGroup: CrmGroup?

    @Binding var isAddingNewGroup: Bool
    @Binding var newGroupName: String

    // ✅ Parent owns sheet. Child just requests “edit selected group”
    let onEditSelectedGroup: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Pin Name")
                        .font(.headline)
                        .foregroundColor(Color("Dark Blue"))
                    TextField("Enter Pin name", text: $breadcrumbName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Group")
                        .font(.headline)
                        .foregroundColor(Color("Dark Blue"))

                    Picker("Select group", selection: $selectedGroup) {
                        Text("None").tag(Optional<CrmGroup>.none)
                        ForEach(groups) { group in
                            Text(group.groupName ?? "Unnamed Group")
                                .tag(Optional(group))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Edit Selected Group") {
                        onEditSelectedGroup()
                    }
                    .disabled(selectedGroup == nil)
                    .opacity(selectedGroup == nil ? 0.5 : 1.0)

                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAddingNewGroup.toggle()
                                if !isAddingNewGroup { newGroupName = "" }
                                if isAddingNewGroup { selectedGroup = nil }
                            }
                        }) {
                            Text(isAddingNewGroup ? "Cancel New Group" : "+ Add New Group")
                                .font(.subheadline)
                        }

                        Spacer()
                    }

                    if isAddingNewGroup {
                        TextField("New group name", text: $newGroupName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                VStack(alignment: .leading) {
                    Text("Note")
                        .font(.headline)
                        .foregroundColor(Color("Dark Blue"))
                    TextEditor(text: $note)
                        .frame(height: 100)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 5)
        }
    }
}




//import SwiftUI
//import CoreData
//
//struct EditBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//    @ObservedObject var breadcrumb: Breadcrumb
//
//    @State private var updatedName: String
//    @State private var updatedNote: String
//    @State private var updatedGroupName: String
//    @State private var selectedImage: UIImage?
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//
//    init(breadcrumb: Breadcrumb) {
//        self.breadcrumb = breadcrumb
//        _updatedName = State(initialValue: breadcrumb.name ?? "")
//        _updatedNote = State(initialValue: breadcrumb.note ?? "")
//        _updatedGroupName = State(initialValue: breadcrumb.crmGroup?.groupName ?? "")
//    }
//
//    var body: some View {
//        VStack {
//            // Header
//            Text("Edit your Pin details!")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Input Section
//                    AddBreadcrumbInputSection(
//                        breadcrumbName: $updatedName,
//                        groupName: $updatedGroupName,
//                        note: $updatedNote
//                    )
//
//                    // Image Section
//                    EditBreadcrumbImageSection(
//                        breadcrumb: breadcrumb,
//                        selectedImage: $selectedImage,
//                        showCamera: $showCamera,
//                        showImagePicker: $showImagePicker
//                    )
//                }
//                .padding(.horizontal)
//            }
//
//            // Save Button
//            Button(action: saveChanges) {
//                Text("Save Changes")
//                    .font(.headline)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color("Dark Orange"))
//                    .foregroundColor(.white)
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//                    .padding(.horizontal)
//            }
//        }
//        .background(Color(.systemGroupedBackground).ignoresSafeArea())
//        .navigationTitle("Edit Pin")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.pop() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//    }
//
//    // MARK: - Save Changes Logic
//    private func saveChanges() {
//        breadcrumb.name = updatedName
//        breadcrumb.note = updatedNote
//
//        // Assign to the updated group
//        if !updatedGroupName.isEmpty {
//            let groupFetchRequest: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
//            groupFetchRequest.predicate = NSPredicate(format: "groupName == %@", updatedGroupName)
//
//            do {
//                let groups = try viewContext.fetch(groupFetchRequest)
//                if let existingGroup = groups.first {
//                    breadcrumb.crmGroup = existingGroup
//                } else {
//                    let newGroup = CrmGroup(context: viewContext)
//                    newGroup.id = UUID()
//                    newGroup.dateCreated = Date()
//                    newGroup.groupName = updatedGroupName
//                    newGroup.groupDescription = "Created from Pin"
//                    breadcrumb.crmGroup = newGroup
//                }
//            } catch {
//                print("Error fetching or creating CrmGroup: \(error)")
//            }
//        }
//
//        // Save image if available
//        if let image = selectedImage {
//            breadcrumb.photoURL = saveImageLocally(image)
//        }
//
//        do {
//            try viewContext.save()
//            dismiss()
//        } catch {
//            print("Failed to save changes: \(error.localizedDescription)")
//        }
//    }
//
//    private func saveImageLocally(_ image: UIImage) -> String {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            return fileName
//        }
//        return ""
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//struct EditBreadcrumbImageSection: View {
//    let breadcrumb: Breadcrumb
//    @Binding var selectedImage: UIImage?
//    @Binding var showCamera: Bool
//    @Binding var showImagePicker: Bool
//
//    var body: some View {
//        Section {
//            ZStack {
//                if let image = selectedImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(maxWidth: .infinity)
//                        .cornerRadius(15)
//                        .shadow(radius: 5)
//                        .padding(.bottom, 10)
//                } else if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(maxWidth: .infinity)
//                        .cornerRadius(15)
//                        .shadow(radius: 5)
//                        .padding(.bottom, 10)
//                } else {
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(maxWidth: .infinity, maxHeight: 300)
//                        .overlay(
//                            Text("No Image Available")
//                                .font(.headline)
//                                .foregroundColor(.gray)
//                        )
//                        .cornerRadius(15)
//                        .padding(.horizontal, 20)
//                }
//            }
//
//            HStack(spacing: 40) {
//                Button(action: { showCamera = true }) {
//                    Image(systemName: "camera")
//                        .font(.largeTitle)
//                        .foregroundColor(Color("Dark Blue"))
//                        .padding()
//                        .background(Color.white)
//                        .clipShape(Circle())
//                        .shadow(radius: 5)
//                }
//
//                Button(action: { showImagePicker = true }) {
//                    Image(systemName: "photo.on.rectangle")
//                        .font(.largeTitle)
//                        .foregroundColor(Color("Dark Blue"))
//                        .padding()
//                        .background(Color.white)
//                        .clipShape(Circle())
//                        .shadow(radius: 5)
//                }
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//    
//
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//struct AddBreadcrumbInputSection: View {
//    @Binding var breadcrumbName: String
//    @Binding var groupName: String
//    @Binding var note: String
//
//    var body: some View {
//        Section {
//            VStack(alignment: .leading, spacing: 15) {
//                // Breadcrumb Name
//                VStack(alignment: .leading) {
//                    Text("Pin Name")
//                        .font(.headline)
//                        .foregroundColor(Color("Dark Blue"))
//                    TextField("Enter Pin name", text: $breadcrumbName)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                }
//
//                // Group Name
//                VStack(alignment: .leading) {
//                    Text("Group Name")
//                        .font(.headline)
//                        .foregroundColor(Color("Dark Blue"))
//                    TextField("Enter group name", text: $groupName)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                }
//
//                // Note
//                VStack(alignment: .leading) {
//                    Text("Note")
//                        .font(.headline)
//                        .foregroundColor(Color("Dark Blue"))
//                    TextEditor(text: $note)
//                        .frame(height: 100)
//                        .cornerRadius(10)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 10)
//                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
//                        )
//                }
//            }
//            .padding()
//            .background(Color.white)
//            .cornerRadius(15)
//            .shadow(radius: 5)
//        }
//    }
//}
