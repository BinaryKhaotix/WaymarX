//
//  GroupsListView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/27/24.
//
import SwiftUI
import CoreData

struct GroupsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel

    @FetchRequest(
        entity: CrmGroup.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.dateCreated, ascending: true)]
    ) private var groups: FetchedResults<CrmGroup>

    @State private var selectedTab: Tab = .groups
    @State private var selectedGroupName: String = "All Groups"

    @State private var showGroupEditor = false
    @State private var groupToEdit: CrmGroup?

    @State private var isEditing = false
    @State private var selectedGroupsToDelete: Set<CrmGroup> = []
    @State private var showMultiDeleteConfirmation = false

    // Swipe delete confirmation
    @State private var showSingleDeleteConfirmation = false
    @State private var groupPendingSwipeDelete: CrmGroup?

    var body: some View {

        GeometryReader { geometry in
            
            let isLandscape = geometry.size.width > geometry.size.height
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(uniqueGroupNames(), id: \.self) { groupName in
                            if let group = groups.first(where: { $0.groupName == groupName }) {
                                
                                SwipeToDeleteRow(
                                    isEnabled: !isEditing,
                                    onDeleteTapped: {
                                        groupPendingSwipeDelete = group
                                        showSingleDeleteConfirmation = true
                                    }
                                ) {
                                    rowContent(for: group)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // MARK: - AdMob Banner
                if !isLandscape {
                    WaymarXBannerView()
                }
                
                BottomNavigationBar(
                    selectedTab: $selectedTab,
                    onHome: { navigationModel.path = [.dashboard] },
                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
                    onGroups: { navigationModel.path.append(.groupsList) },
                    onProfile: { navigationModel.path.append(.editProfile) },
                    showHome: true,
                    showDropCrumb: true,
                    showMap: false,
                    showGroups: false,
                    showProfile: true
                )
                .frame(height: 60)
            }
        }
        .background(Color(.systemBackground)
            .ignoresSafeArea())
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Done") {
                        isEditing = false
                        selectedGroupsToDelete.removeAll()
                    }
                } else {
                    Button(action: { navigationModel.path.removeLast() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                            Text("Back")
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isEditing {
                    Button(action: {
                        showMultiDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(selectedGroupsToDelete.isEmpty)
                } else {
                    Button(action: {
                        groupToEdit = nil
                        showGroupEditor = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }

                    Button("Edit") {
                        isEditing = true
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showGroupEditor, onDismiss: {
            groupToEdit = nil
        }) {
            GroupEditorView(groupToEdit: groupToEdit)
                .environment(\.managedObjectContext, viewContext)
        }

        // Multi-delete alert (existing)
        .alert("Delete Groups?", isPresented: $showMultiDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedGroups()
            }
        } message: {
            Text("Are you sure you want to delete the selected groups? This action cannot be undone.")
        }

        // Single swipe-delete alert (new)
        .alert("Delete Group?", isPresented: $showSingleDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                groupPendingSwipeDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let group = groupPendingSwipeDelete {
                    deleteGroup(group)
                }
                groupPendingSwipeDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this group? This action cannot be undone.")
        }
    }

    // MARK: - Row Content

    @ViewBuilder
    private func rowContent(for group: CrmGroup) -> some View {
        HStack {
            if isEditing {
                Button(action: {
                    toggleSelection(for: group)
                }) {
                    Image(systemName: selectedGroupsToDelete.contains(group) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.red)
                }
            }

            // IMPORTANT: Not a Button anymore (Buttons steal drag gestures)
            GroupTileView(group: group)
                .contentShape(Rectangle()) // makes the whole tile tappable
                .onTapGesture {
                    guard !isEditing else { return }
                    selectedGroupName = group.groupName ?? "Unknown"
                    navigationModel.path.append(.groupCrumbs(groupName: group.groupName ?? "Unknown"))
                }

            Spacer()

            if !isEditing {
                Button(action: {
                    groupToEdit = group
                    showGroupEditor = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading) // helps fully cover swipe background
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    // MARK: - Helper Methods

    private func uniqueGroupNames() -> [String] {
        let uniqueGroupNames = Set(groups.compactMap { $0.groupName })
        return uniqueGroupNames.sorted()
    }

    private func toggleSelection(for group: CrmGroup) {
        if selectedGroupsToDelete.contains(group) {
            selectedGroupsToDelete.remove(group)
        } else {
            selectedGroupsToDelete.insert(group)
        }
    }

    private func deleteSelectedGroups() {
        for group in selectedGroupsToDelete {
            viewContext.delete(group)
        }
        selectedGroupsToDelete.removeAll()
        saveContext()
    }

    private func deleteGroup(_ group: CrmGroup) {
        viewContext.delete(group)
        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}

//
// MARK: - SwipeToDeleteRow (custom swipe, no List)
//
//
// MARK: - SwipeToDeleteRow (custom swipe, no List)
//
private struct SwipeToDeleteRow<Content: View>: View {
    let isEnabled: Bool
    let onDeleteTapped: () -> Void
    let content: Content

    @State private var offsetX: CGFloat = 0
    @GestureState private var dragX: CGFloat = 0
    @GestureState private var isHorizontalDrag: Bool = false

    private let actionWidth: CGFloat = 88
    private let openThreshold: CGFloat = 44
    private let cornerRadius: CGFloat = 10

    init(
        isEnabled: Bool,
        onDeleteTapped: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isEnabled = isEnabled
        self.onDeleteTapped = onDeleteTapped
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()

            // Delete action BEHIND the row, only visible when swiped
            HStack(spacing: 0) {
                Spacer()

                Button {
                    // Close first, then confirm
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        offsetX = 0
                    }
                    onDeleteTapped()
                } label: {
                    Image(systemName: "trash")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: actionWidth, height: 130)
                        .contentShape(Rectangle())
                }
                .frame(width: actionWidth)
                .background(Color.red)
            }
            .opacity(revealProgress)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Foreground row slides left
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .offset(x: computedOffset)
                // KEY CHANGE:
                // Use simultaneousGesture so ScrollView can still scroll vertically.
                .simultaneousGesture(isEnabled ? dragGesture : nil)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: offsetX)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    // How much to show the delete action (0 closed, 1 fully open)
    private var revealProgress: Double {
        let x = abs(computedOffset)
        return Double(min(1, max(0, x / actionWidth)))
    }

    private var computedOffset: CGFloat {
        let raw = offsetX + (isHorizontalDrag ? dragX : 0)
        // Clamp: closed (0) to open (-actionWidth)
        return min(0, max(-actionWidth, raw))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($isHorizontalDrag) { value, state, _ in
                // Lock-in only if it’s clearly horizontal
                if abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                    state = true
                } else {
                    state = false
                }
            }
            .updating($dragX) { value, state, _ in
                // Only drive horizontal offset if we’ve locked into horizontal
                if abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                    state = value.translation.width
                } else {
                    state = 0
                }
            }
            .onEnded { value in
                // If it wasn’t a horizontal swipe, don’t do anything (let ScrollView have it)
                guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }

                let predicted = offsetX + value.predictedEndTranslation.width
                if predicted < -openThreshold {
                    offsetX = -actionWidth
                } else {
                    offsetX = 0
                }
            }
    }
}




//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @FetchRequest(
//        entity: CrmGroup.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.dateCreated, ascending: true)]
//    ) private var groups: FetchedResults<CrmGroup>
//
//    @State private var selectedTab: Tab = .groups
//    @State private var selectedGroupName: String = "All Groups"
//    @State private var showGroupEditor = false
//    @State private var groupToEdit: CrmGroup?
//    @State private var isEditing = false
//    @State private var selectedGroupsToDelete: Set<CrmGroup> = []
//    @State private var showDeleteConfirmation = false
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                VStack(spacing: 10) {
//                    ForEach(uniqueGroupNames(), id: \.self) { groupName in
//                        if let group = groups.first(where: { $0.groupName == groupName }) {
//                            HStack {
//                                if isEditing {
//                                    Button(action: {
//                                        toggleSelection(for: group)
//                                    }) {
//                                        Image(systemName: selectedGroupsToDelete.contains(group) ? "checkmark.circle.fill" : "circle")
//                                            .foregroundColor(.red)
//                                    }
//                                }
//
//                                Button(action: {
//                                    if !isEditing {
//                                        selectedGroupName = group.groupName ?? "Unknown"
//                                        navigationModel.path.append(.groupCrumbs(groupName: group.groupName ?? "Unknown"))
//                                    }
//                                }) {
//                                    GroupTileView(group: group)
//                                }
//                                .disabled(isEditing)
//
//                                Spacer()
//
//                                if !isEditing {
//                                    Button(action: {
//                                        groupToEdit = group
//                                        showGroupEditor = true
//                                    }) {
//                                        Image(systemName: "pencil")
//                                            .foregroundColor(.blue)
//                                    }
//                                }
//                            }
//                            .padding()
//                            .background(Color.gray.opacity(0.1))
//                            .cornerRadius(10)
//                            .shadow(radius: 2)
//                        }
//                    }
//                }
//                .padding()
//            }
//
//            BottomNavigationBar(
//                selectedTab: $selectedTab,
//                onHome: { navigationModel.path = [.dashboard] },
//                onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                onGroups: { navigationModel.path.append(.groupsList) },
//                onProfile: { navigationModel.path.append(.editProfile) },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: false,
//                showGroups: false,
//                showProfile: true
//            )
//            .frame(height: 60)
//        }
//        .background(Color.white.ignoresSafeArea())
//        .navigationTitle("Groups")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                if isEditing {
//                    Button("Done") {
//                        isEditing = false
//                        selectedGroupsToDelete.removeAll()
//                    }
//                } else {
//                    Button(action: { navigationModel.path.removeLast() }) {
//                        HStack {
//                            Image(systemName: "chevron.left")
//                                .foregroundColor(.white)
//                            Text("Back")
//                                .foregroundColor(.white)
//                        }
//                    }
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                if isEditing {
//                    Button(action: {
//                        showDeleteConfirmation = true
//                    }) {
//                        Image(systemName: "trash")
//                            .foregroundColor(.red)
//                    }
//                    .disabled(selectedGroupsToDelete.isEmpty)
//                } else {
//                    Button("Edit") {
//                        isEditing = true
//                    }
//                    .foregroundColor(.white)
//                }
//            }
//        }
//        .sheet(isPresented: $showGroupEditor) {
//            GroupEditorView(groupToEdit: groupToEdit)
//                .environment(\.managedObjectContext, viewContext)
//        }
//        .alert("Delete Groups?", isPresented: $showDeleteConfirmation) {
//            Button("Cancel", role: .cancel) {}
//            Button("Delete", role: .destructive) {
//                deleteSelectedGroups()
//            }
//        } message: {
//            Text("Are you sure you want to delete the selected groups? This action cannot be undone.")
//        }
//    }
//
//    // MARK: - Helper Methods
//
//    /// Returns unique group names from the fetched results
//    private func uniqueGroupNames() -> [String] {
//        let uniqueGroupNames = Set(groups.compactMap { $0.groupName })
//        return uniqueGroupNames.sorted()
//    }
//
//    /// Toggles selection for a specific group
//    private func toggleSelection(for group: CrmGroup) {
//        if selectedGroupsToDelete.contains(group) {
//            selectedGroupsToDelete.remove(group)
//        } else {
//            selectedGroupsToDelete.insert(group)
//        }
//    }
//
//    /// Deletes the selected groups from Core Data
//    private func deleteSelectedGroups() {
//        for group in selectedGroupsToDelete {
//            viewContext.delete(group)
//        }
//        selectedGroupsToDelete.removeAll()
//        saveContext()
//    }
//
//    /// Saves the Core Data context
//    private func saveContext() {
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save context: \(error.localizedDescription)")
//        }
//    }
//}






//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @FetchRequest(
//        entity: CrmGroup.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.dateCreated, ascending: true)]
//    ) private var groups: FetchedResults<CrmGroup>
//
//    @State private var selectedTab: Tab = .groups
//    @State private var selectedGroupName: String = "All Groups"
//    @State private var showGroupEditor = false
//    @State private var groupToEdit: CrmGroup?
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                VStack(spacing: 10) {
//                    ForEach(groups) { group in
//                        HStack {
//                            // Navigate to group details
//                            Button(action: {
//                                selectedGroupName = group.groupName ?? "Unknown"
//                                navigationModel.path.append(.groupCrumbs(groupName: group.groupName ?? "Unknown"))
//                            }) {
//                                GroupTileView(group: group)
//                            }
//
//                            Spacer()
//
//                            // Edit Button
//                            Button(action: {
//                                groupToEdit = group
//                                showGroupEditor = true
//                            }) {
//                                Image(systemName: "pencil")
//                                    .foregroundColor(.blue)
//                            }
//                        }
//                        .padding()
//                        .background(Color.gray.opacity(0.1))
//                        .cornerRadius(10)
//                        .shadow(radius: 2)
//                    }
//                }
//                .padding()
//            }
//
//            // Bottom Navigation Bar
//            BottomNavigationBar(
//                selectedTab: $selectedTab,
//                onHome: {
//                    navigationModel.path = [.dashboard]
//                },
//                onDropCrumb: {
//                    navigationModel.path.append(.addBreadcrumb)
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: false,
//                showGroups: false,
//                showProfile: true
//            )
//            .frame(height: 60)
//        }
//        .background(Color.white.ignoresSafeArea())
//        .navigationTitle("Group: \(selectedGroupName)")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.path.removeLast() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    groupToEdit = nil
//                    showGroupEditor = true
//                }) {
//                    Image(systemName: "plus")
//                        .foregroundColor(.white)
//                }
//            }
//        }
//        .sheet(isPresented: $showGroupEditor) {
//            GroupEditorView(groupToEdit: groupToEdit)
//                .environment(\.managedObjectContext, viewContext)
//        }
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @FetchRequest(
//        entity: CrmGroup.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.dateCreated, ascending: true)]
//    ) private var groups: FetchedResults<CrmGroup>
//
//    @State private var selectedTab: Tab = .groups
//    @State private var selectedcrmGroup?.groupName: String = "All Groups"
//    @State private var showGroupEditor = false
//    @State private var groupToEdit: CrmGroup?
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                VStack(spacing: 10) {
//                    ForEach(groups) { group in
//                        HStack {
//                            // Navigate to group details
//                            Button(action: {
//                                selectedcrmGroup?.groupName = group.crmGroup?.groupName ?? "Unknown"
//                                navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName ?? "Unknown"))
//                            }) {
//                                GroupTileView(group: group)
//                            }
//
//                            Spacer()
//
//                            // Edit Button
//                            Button(action: {
//                                groupToEdit = group
//                                showGroupEditor = true
//                            }) {
//                                Image(systemName: "pencil")
//                                    .foregroundColor(.blue)
//                            }
//                        }
//                        .padding()
//                        .background(Color.gray.opacity(0.1))
//                        .cornerRadius(10)
//                        .shadow(radius: 2)
//                    }
//                }
//                .padding()
//            }
//
//            // Bottom Navigation Bar
//            BottomNavigationBar(
//                selectedTab: $selectedTab,
//                onHome: {
//                    navigationModel.path = [.dashboard]
//                },
//                onDropCrumb: {
//                    navigationModel.path.append(.addBreadcrumb)
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: false,
//                showGroups: false,
//                showProfile: true
//            )
//            .frame(height: 60)
//        }
//        .background(Color.white.ignoresSafeArea())
//        .navigationTitle("Group: \(selectedcrmGroup?.groupName)")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.path.removeLast() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    groupToEdit = nil
//                    showGroupEditor = true
//                }) {
//                    Image(systemName: "plus")
//                        .foregroundColor(.blue)
//                }
//            }
//        }
//        .sheet(isPresented: $showGroupEditor) {
//            GroupEditorView(groupToEdit: groupToEdit)
//                .environment(\.managedObjectContext, viewContext)
//        }
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//    @FetchRequest(
//        entity: CrmGroup.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.dateCreated, ascending: true)]
//    ) private var groups: FetchedResults<CrmGroup>
//    
//    @State private var selectedTab: Tab = .groups // Track the selected tab for BottomNavigationBar
//    @State private var selectedcrmGroup?.groupName: String = "All Groups" // Default title
//    @State private var showGroupEditor = false // Show editor view
//    @State private var groupToEdit: CrmGroup? // Group to edit
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                VStack(spacing: 10) {
//                    ForEach(groups) { group in
//                        HStack {
//                            Button(action: {
//                                selectedcrmGroup?.groupName = group.crmGroup?.groupName ?? "Unknown"
//                                navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName ?? "Unknown"))
//                            }) {
//                                GroupTileView(
//                                    crmGroup?.groupName: group.crmGroup?.groupName ?? "Unknown",
//                                    image: randomImage(from: group.breadcrumbsArray)
//                                )
//                            }
//
//                            Spacer()
//
//                            // Edit Button
//                            Button(action: {
//                                groupToEdit = group
//                                showGroupEditor = true
//                            }) {
//                                Image(systemName: "pencil")
//                                    .foregroundColor(.blue)
//                            }
//                        }
//                        .padding()
//                        .background(Color.gray.opacity(0.1))
//                        .cornerRadius(10)
//                        .shadow(radius: 2)
//                    }
//                }
//                .padding()
//            }
//
//            // Bottom Navigation Bar
//            BottomNavigationBar(
//                selectedTab: $selectedTab,
//                onHome: {
//                    navigationModel.path = [.dashboard]
//                },
//                onDropCrumb: {
//                    navigationModel.path.append(.addBreadcrumb)
//                },
//                onMap: {
//                    // Implement map logic if required
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: false,
//                showGroups: false,
//                showProfile: true
//            )
//            .frame(height: 60)
//        }
//        .background(Color.white.ignoresSafeArea())
//        .navigationTitle("Group: \(selectedcrmGroup?.groupName)")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.path.removeLast() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    groupToEdit = nil
//                    showGroupEditor = true
//                }) {
//                    Image(systemName: "plus")
//                        .foregroundColor(.blue)
//                }
//            }
//        }
//        .sheet(isPresented: $showGroupEditor) {
//            GroupEditorView(groupToEdit: groupToEdit)
//                .environment(\.managedObjectContext, viewContext)
//        }
//    }
//
//    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
//        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
//        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
//           let fileName = randomBreadcrumb.photoURL {
//            return loadImage(from: fileName)
//        }
//        return UIImage(named: "defaultGroupImage")
//    }
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
//        return url.flatMap { UIImage(contentsOfFile: $0.path) }
//    }
//}
//
//extension CrmGroup {
//    var breadcrumbsArray: [Breadcrumb] {
//        (breadcrumbs as? Set<Breadcrumb>)?.sorted { $0.dateDropped ?? Date() < $1.dateDropped ?? Date() } ?? []
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [],
//        predicate: NSPredicate(format: "crmGroup?.groupName != NULL")
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//    
//    @State private var selectedTab: Tab = .groups // Track the selected tab for BottomNavigationBar
//    @State private var selectedcrmGroup?.groupName: String = "All Groups" // Default title
//
//    // Group breadcrumbs by their crmGroup?.groupName
//    var groups: [GroupData] {
//        let grouped = Dictionary(grouping: breadcrumbs, by: { $0.crmGroup?.groupName ?? "Unknown" })
//        return grouped.map { GroupData(crmGroup?.groupName: $0.key, breadcrumbs: $0.value) }
//            .sorted { $0.crmGroup?.groupName < $1.crmGroup?.groupName }
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                TileContainerVerticalView(title: "All Groups", items: groups) { group in
//                    Button(action: {
//                        selectedcrmGroup?.groupName = group.crmGroup?.groupName // Update dynamic title
//                        navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName))
//                    }) {
//                        GroupTileView(crmGroup?.groupName: group.crmGroup?.groupName, image: randomImage(from: group.breadcrumbs))
//                    }
//                }
//                .padding()
//            }
//
//            // Bottom Navigation Bar
//            BottomNavigationBar(
//                selectedTab: $selectedTab,
//                onHome: {
//                    navigationModel.path = [.dashboard]
//                },
//                onDropCrumb: {
//                    navigationModel.path.append(.addBreadcrumb)
//                },
//                onMap: {
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(breadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,        // Show Home button
//                showDropCrumb: true,  // Show Drop Crumb button
//                showMap: false,       // Hide Map button
//                showGroups: false,    // Hide Groups button
//                showProfile: true     // Show Profile button
//            )
//            .frame(height: 60)
//        }
//        .background(Color.white.ignoresSafeArea())
//        .navigationTitle("Group: \(selectedcrmGroup?.groupName)")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.path.removeLast() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//
//        .onAppear {
//            selectedcrmGroup?.groupName = "All Groups" // Set default title on view load
//        }
//    }
//
//    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
//        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
//        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
//           let fileName = randomBreadcrumb.photoURL {
//            return loadImage(from: fileName)
//        }
//        return UIImage(named: "defaultGroupImage")
//    }
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
//        return url.flatMap { UIImage(contentsOfFile: $0.path) }
//    }
//}
//
//struct GroupData: Identifiable {
//    var id: String { crmGroup?.groupName }
//    let crmGroup?.groupName: String
//    let breadcrumbs: [Breadcrumb]
//}


//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [],
//        predicate: NSPredicate(format: "crmGroup?.groupName != NULL")
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    @State private var selectedTab: Tab = .groups // Track the selected tab for BottomNavigationBar
//
//    // Group breadcrumbs by their crmGroup?.groupName
//    var groups: [GroupData] {
//        let grouped = Dictionary(grouping: breadcrumbs, by: { $0.crmGroup?.groupName ?? "Unknown" })
//        return grouped.map { GroupData(crmGroup?.groupName: $0.key, breadcrumbs: $0.value) }
//            .sorted { $0.crmGroup?.groupName < $1.crmGroup?.groupName }
//    }
//
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                TileContainerView(title: "All Groups", items: groups) { group in
//                    Button(action: {
//                        navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName))
//                    }) {
//                        GroupTileView(crmGroup?.groupName: group.crmGroup?.groupName, image: randomImage(from: group.breadcrumbs))
//                    }
//                }
//                .padding()
//            }
//
//            // Bottom Navigation Bar
//            BottomNavigationBar(
//                selectedTab: $selectedTab,
//                onHome: {
//                    navigationModel.path = [.dashboard]
//                },
//                onDropCrumb: {
//                    navigationModel.path.append(.addBreadcrumb)
//                },
//                onMap: {
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(breadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,        // Show Home button
//                showDropCrumb: true,  // Hide Drop Crumb button
//                showMap: false,         // Show Map button
//                showGroups: false,      // Show Groups button
//                showProfile: true     // Hide Profile button
//            )
//            .frame(height: 60)
//        }
//        .background(Color.white.ignoresSafeArea())
//        .navigationTitle("Group: \(crmGroup?.groupName)")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
//        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
//        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
//           let fileName = randomBreadcrumb.photoURL {
//            return loadImage(from: fileName)
//        }
//        return UIImage(named: "defaultGroupImage")
//    }
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
//        return url.flatMap { UIImage(contentsOfFile: $0.path) }
//    }
//}
//
//struct GroupData: Identifiable {
//    var id: String { crmGroup?.groupName }
//    let crmGroup?.groupName: String
//    let breadcrumbs: [Breadcrumb]
//}


//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [],
//        predicate: NSPredicate(format: "crmGroup?.groupName != NULL")
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    // Group breadcrumbs by their crmGroup?.groupName
//    var groups: [GroupData] {
//        let grouped = Dictionary(grouping: breadcrumbs, by: { $0.crmGroup?.groupName ?? "Unknown" })
//        return grouped.map { GroupData(crmGroup?.groupName: $0.key, breadcrumbs: $0.value) }
//            .sorted { $0.crmGroup?.groupName < $1.crmGroup?.groupName }
//    }
//
//    var body: some View {
//        ScrollView {
//            TileContainerView(title: "All Groups", items: groups) { group in
//                Button(action: {
//                    navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName))
//                }) {
//                    GroupTileView(crmGroup?.groupName: group.crmGroup?.groupName, image: randomImage(from: group.breadcrumbs))
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Groups")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
//        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
//        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
//           let fileName = randomBreadcrumb.photoURL {
//            return loadImage(from: fileName)
//        }
//        return UIImage(named: "defaultGroupImage")
//    }
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
//        return url.flatMap { UIImage(contentsOfFile: $0.path) }
//    }
//}
//
//struct GroupData: Identifiable {
//    var id: String { crmGroup?.groupName }
//    let crmGroup?.groupName: String
//    let breadcrumbs: [Breadcrumb]
//}
//



//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [],
//        predicate: NSPredicate(format: "crmGroup?.groupName != NULL")
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    // Group breadcrumbs by their crmGroup?.groupName, ensuring no nil keys
//    var groups: [GroupData] {
//        let grouped = Dictionary(grouping: breadcrumbs, by: { $0.crmGroup?.groupName ?? "Unknown" })
//        return grouped.map { GroupData(crmGroup?.groupName: $0.key, breadcrumbs: $0.value) }
//            .sorted { $0.crmGroup?.groupName < $1.crmGroup?.groupName }
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                // Add title and grid-like container
//                TileContainerView(title: "All Groups", items: groups) { group in
//                    Button(action: {
//                        navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName))
//                    }) {
//                        GroupTileView(crmGroup?.groupName: group.crmGroup?.groupName)
//                    }
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Groups")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
//
//struct GroupData: Identifiable {
//    var id: String { crmGroup?.groupName } // Use crmGroup?.groupName as the unique identifier
//    let crmGroup?.groupName: String
//    let breadcrumbs: [Breadcrumb]
//}




//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [],
//        predicate: NSPredicate(format: "crmGroup?.groupName != NULL")
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    // Group breadcrumbs by their crmGroup?.groupName, ensuring no nil keys
//    var groups: [GroupData] {
//        let grouped = Dictionary(grouping: breadcrumbs, by: { $0.crmGroup?.groupName ?? "Unknown" })
//        return grouped.map { GroupData(crmGroup?.groupName: $0.key, breadcrumbs: $0.value) }
//            .sorted { $0.crmGroup?.groupName < $1.crmGroup?.groupName }
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                ForEach(groups, id: \.crmGroup?.groupName) { group in
//                    let randomImage = randomImage(from: group.breadcrumbs)
//                    Button(action: {
//                        navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName))
//                    }) {
//                        GroupTileView(crmGroup?.groupName: group.crmGroup?.groupName)
//                    }
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Groups")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    /// Fetch a random image from breadcrumbs in the group
//    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
//        // Filter breadcrumbs with a valid photoURL
//        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
//        // Randomly select a breadcrumb with an image
//        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
//           let fileName = randomBreadcrumb.photoURL {
//            return loadImage(from: fileName)
//        }
//        // Provide a fallback default image if no photos are available
//        return UIImage(named: "defaultGroupImage")
//    }
//
//    /// Load the image from file
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
//        return url.flatMap { UIImage(contentsOfFile: $0.path) }
//    }
//}
//
//struct GroupData: Identifiable {
//    var id: String { crmGroup?.groupName } // Use crmGroup?.groupName as the unique identifier
//    let crmGroup?.groupName: String
//    let breadcrumbs: [Breadcrumb]
//}


//import SwiftUI
//import CoreData
//
//struct GroupsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [],
//        predicate: NSPredicate(format: "crmGroup?.groupName != NULL")
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    // Group breadcrumbs by their crmGroup?.groupName, ensuring no nil keys
//    var groups: [GroupData] {
//        let grouped = Dictionary(grouping: breadcrumbs, by: { $0.crmGroup?.groupName ?? "Unknown" })
//        return grouped.map { GroupData(crmGroup?.groupName: $0.key, breadcrumbs: $0.value) }
//            .sorted { $0.crmGroup?.groupName < $1.crmGroup?.groupName }
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                ForEach(groups, id: \.crmGroup?.groupName) { group in
//                    if !group.breadcrumbs.isEmpty {
//                        let randomImage = randomImage(from: group.breadcrumbs)
//                        Button(action: {
//                            navigationModel.path.append(.groupCrumbs(crmGroup?.groupName: group.crmGroup?.groupName))
//                        }) {
//                            GroupTileView(crmGroup?.groupName: group.crmGroup?.groupName, image: randomImage) // Reusing existing GroupTileView
//                        }
//                    }
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Groups")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
//        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
//        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
//           let fileName = randomBreadcrumb.photoURL {
//            return loadImage(from: fileName)
//        }
//        return nil // Return nil if no image is available
//    }
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
//        return url.flatMap { UIImage(contentsOfFile: $0.path) }
//    }
//}
//
//struct GroupData: Identifiable {
//    var id: String { crmGroup?.groupName } // Use crmGroup?.groupName as the unique identifier
//    let crmGroup?.groupName: String
//    let breadcrumbs: [Breadcrumb]
//}
