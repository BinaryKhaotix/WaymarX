//
//  GroupCrumbsView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/12/24.
//
import SwiftUI
import CoreData

struct GroupCrumbsView: View {
    let groupName: String
    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
    @FetchRequest private var matchingGroups: FetchedResults<CrmGroup>
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedTab: Tab = .home
    @State private var breadcrumbToDelete: Breadcrumb? = nil
    @State private var showDeleteConfirmation = false

    // Group Import/Export UI
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingImportPicker = false
    @State private var transferError: String?

    init(groupName: String) {
        self.groupName = groupName
        self._matchingGroups = FetchRequest(
            entity: CrmGroup.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.dateCreated, ascending: true)],
            predicate: NSPredicate(format: "groupName == %@", groupName)
        )

        self._groupBreadcrumbs = FetchRequest(
            entity: Breadcrumb.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
            predicate: NSPredicate(format: "crmGroup.groupName == %@", groupName)
        )
    }

    // ✅ Make a real Swift array once. This avoids type-checker meltdown.
    private var contextCrumbs: [Breadcrumb] {
        groupBreadcrumbs.filter { breadcrumb in
            !breadcrumb.isWantToGo
        }
    }
    
    private var groupBottomNavigationBar: some View {
        BottomNavigationBar(
            selectedTab: $selectedTab,

            onHome: {
                navigationModel.path = [.dashboard]
            },

            onDropCrumb: {
                navigationModel.path.append(
                    .addBreadcrumbToGroup(groupname: groupName)
                )
            },

            onMap: {
                navigationModel.path.append(
                    .groupCrumbMap(groupBreadcrumbs: contextCrumbs)
                )
            },

            onGroups: {
                navigationModel.path.append(.groupsList)
            },

            onProfile: {
                navigationModel.path.append(.editProfile)
            },

            showHome: true,
            showDropCrumb: true,
            showMap: true,
            showGroups: false,
            showProfile: false
        )
        .frame(height: 60)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {

                    // ✅ Use objectID instead of \.self (more stable for Core Data objects)
                    ForEach(contextCrumbs, id: \.objectID) { breadcrumb in
                        Button {
                            // ✅ Pass a plain array, not FetchedResults
                            navigationModel.pushBreadcrumbDetail(in: contextCrumbs, selected: breadcrumb)
                        } label: {
                            BreadcrumbTileView(breadcrumb: breadcrumb)
                                .environmentObject(locationManager)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if let group = breadcrumb.value(forKey: "crmGroup") as? CrmGroup {
                                Button {
                                    ExportManager.exportGroup(group) { url in
                                        DispatchQueue.main.async {
                                            exportURL = url
                                            if url != nil {
                                                showingShareSheet = true
                                            } else {
                                                transferError = "Export failed."
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Export Group", systemImage: "square.and.arrow.up")
                                }
                            }

                            Button(role: .destructive) {
                                breadcrumbToDelete = breadcrumb
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            // MARK: - AdMob Banner
            WaymarXBannerView()

            groupBottomNavigationBar
        }
        .navigationTitle(groupName)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Group ZIP", systemImage: "square.and.arrow.down")
                    }

                    if let group = matchingGroups.first {
                        Button {
                            ExportManager.exportGroup(group) { url in
                                DispatchQueue.main.async {
                                    exportURL = url
                                    if url != nil {
                                        showingShareSheet = true
                                    } else {
                                        transferError = "Export failed."
                                    }
                                }
                            }
                        } label: {
                            Label("Export This Group", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            DocumentPicker { pickedURL in
                do {
                    try ImportManager.importGroup(from: pickedURL, context: viewContext)
                } catch {
                    transferError = error.localizedDescription
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .alert("Group Transfer", isPresented: Binding(get: { transferError != nil }, set: { if !$0 { transferError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transferError ?? "")
        }

        .alert("Delete Pin?", isPresented: $showDeleteConfirmation, actions: {
            Button("Delete", role: .destructive, action: confirmDelete)
            Button("Cancel", role: .cancel) { breadcrumbToDelete = nil }
        }, message: {
            Text("Are you sure you want to delete this breadcrumb? This action cannot be undone.")
        })
    }

    private func confirmDelete() {
        guard let breadcrumb = breadcrumbToDelete else { return }
        if let context = breadcrumb.managedObjectContext {
            context.delete(breadcrumb)
            do {
                try context.save()
            } catch {
                print("Failed to delete breadcrumb: \(error.localizedDescription)")
            }
        }
        breadcrumbToDelete = nil
    }
}






// 022626 before group crumb export/import modifications
//
//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//    @State private var selectedTab: Tab = .home
//    @State private var breadcrumbToDelete: Breadcrumb? = nil
//    @State private var showDeleteConfirmation = false
//
//    init(groupName: String) {
//        self.groupName = groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup.groupName == %@", groupName)
//        )
//    }
//
//    // ✅ Make a real Swift array once. This avoids type-checker meltdown.
//    private var contextCrumbs: [Breadcrumb] {
//        Array(groupBreadcrumbs)
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                VStack(spacing: 20) {
//
//                    // ✅ Use objectID instead of \.self (more stable for Core Data objects)
//                    ForEach(contextCrumbs, id: \.objectID) { breadcrumb in
//                        Button {
//                            // ✅ Pass a plain array, not FetchedResults
//                            navigationModel.pushBreadcrumbDetail(in: contextCrumbs, selected: breadcrumb)
//                        } label: {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                                .environmentObject(locationManager)
//                        }
//                        .buttonStyle(.plain)
//                        .contextMenu {
//                            Button(role: .destructive) {
//                                breadcrumbToDelete = breadcrumb
//                                showDeleteConfirmation = true
//                            } label: {
//                                Label("Delete", systemImage: "trash")
//                            }
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
//                onMap: {
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: contextCrumbs))
//                },
//                onGroups: { navigationModel.path.append(.groupsList) },
//                onProfile: { navigationModel.path.append(.editProfile) },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: false,
//                showProfile: false
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(groupName)
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
//        .alert("Delete Pin?", isPresented: $showDeleteConfirmation, actions: {
//            Button("Delete", role: .destructive, action: confirmDelete)
//            Button("Cancel", role: .cancel) { breadcrumbToDelete = nil }
//        }, message: {
//            Text("Are you sure you want to delete this breadcrumb? This action cannot be undone.")
//        })
//    }
//
//    private func confirmDelete() {
//        guard let breadcrumb = breadcrumbToDelete else { return }
//        if let context = breadcrumb.managedObjectContext {
//            context.delete(breadcrumb)
//            do {
//                try context.save()
//            } catch {
//                print("Failed to delete breadcrumb: \(error.localizedDescription)")
//            }
//        }
//        breadcrumbToDelete = nil
//    }
//}



//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//    @State private var selectedTab: Tab = .home
//    @State private var breadcrumbToDelete: Breadcrumb? = nil
//    @State private var showDeleteConfirmation = false
//
//    init(groupName: String) {
//        self.groupName = groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup.groupName == %@", groupName)
//        )
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // Scrollable List of Breadcrumbs
//            ScrollView {
//                VStack(spacing: 20) {
//                    ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                        Button(action: {
//                            // Navigate to BreadcrumbDetailView using NavigationModel
//                            navigationModel.pushBreadcrumbDetail(in: groupBreadcrumbs, selected: breadcrumb)
//                        }) {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                                .environmentObject(locationManager)
//                        }
//                        .buttonStyle(PlainButtonStyle()) // Preserve original styling
//                        .contextMenu {
//                            // Provide delete functionality in the context menu
//                            Button(role: .destructive) {
//                                breadcrumbToDelete = breadcrumb
//                                showDeleteConfirmation = true
//                            } label: {
//                                Label("Delete", systemImage: "trash")
//                            }
//                        }
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
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(groupBreadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: false,
//                showProfile: false
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(groupName)
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
//        .alert("Delete Pin?", isPresented: $showDeleteConfirmation, actions: {
//            Button("Delete", role: .destructive, action: confirmDelete)
//            Button("Cancel", role: .cancel) {
//                breadcrumbToDelete = nil
//            }
//        }, message: {
//            Text("Are you sure you want to delete this breadcrumb? This action cannot be undone.")
//        })
//    }
//
//    // MARK: - Delete Functions
//    private func confirmDelete() {
//        guard let breadcrumb = breadcrumbToDelete else { return }
//        if let context = breadcrumb.managedObjectContext {
//            context.delete(breadcrumb)
//
//            do {
//                try context.save()
//            } catch {
//                print("Failed to delete breadcrumb: \(error.localizedDescription)")
//            }
//        }
//
//        breadcrumbToDelete = nil // Reset after deletion
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//    @State private var selectedTab: Tab = .home
//    @State private var breadcrumbToDelete: Breadcrumb? = nil // Mutable optional
//    @State private var showDeleteConfirmation = false
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // Scrollable List of Breadcrumbs
//            ScrollView {
//                VStack(spacing: 20) {
//                    ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                        Button(action: {
//                            // Navigate to BreadcrumbDetailView using NavigationModel
//                            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                        }) {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                                .environmentObject(locationManager)
//                        }
//                        .buttonStyle(PlainButtonStyle()) // Preserve original styling
//                        .contextMenu { // Optional: Provide delete functionality in the context menu
//                            Button(role: .destructive) {
//                                breadcrumbToDelete = breadcrumb
//                                showDeleteConfirmation = true
//                            } label: {
//                                Label("Delete", systemImage: "trash")
//                            }
//                        }
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
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(groupBreadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: false,
//                showProfile: false
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(crmGroup?.groupName)
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
//        .alert("Delete Crumb?", isPresented: $showDeleteConfirmation, actions: {
//            Button("Delete", role: .destructive, action: confirmDelete)
//            Button("Cancel", role: .cancel, action: { breadcrumbToDelete = nil })
//        }, message: {
//            Text("Are you sure you want to delete this breadcrumb? This action cannot be undone.")
//        })
//    }
//
//    // MARK: - Delete Functions
//    private func initiateDelete(at offsets: IndexSet) {
//        guard let index = offsets.first else { return }
//        breadcrumbToDelete = groupBreadcrumbs[index]
//        showDeleteConfirmation = true
//    }
//
//    private func confirmDelete() {
//        guard breadcrumbToDelete != nil else { return }
//        if let context = breadcrumbToDelete?.managedObjectContext {
//            context.delete(breadcrumbToDelete!)
//
//            do {
//                try context.save()
//            } catch {
//                print("Failed to delete breadcrumb: \(error.localizedDescription)")
//            }
//        }
//
//        breadcrumbToDelete = nil // Reset after deletion
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//    @State private var selectedTab: Tab = .home
//    @State private var breadcrumbToDelete: Breadcrumb? = nil // Mutable optional
//    @State private var showDeleteConfirmation = false
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            List {
//                ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                    Button(action: {
//                        navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                    }) {
//                        BreadcrumbTileView(breadcrumb: breadcrumb)
//                            .environmentObject(locationManager)
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//                .onDelete(perform: initiateDelete) // Add swipe-to-delete
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
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(groupBreadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: false,
//                showProfile: false
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(crmGroup?.groupName)
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
//        .alert("Delete Crumb?", isPresented: $showDeleteConfirmation, actions: {
//            Button("Delete", role: .destructive, action: confirmDelete)
//            Button("Cancel", role: .cancel, action: { breadcrumbToDelete = nil })
//        }, message: {
//            Text("Are you sure you want to delete this breadcrumb? This action cannot be undone.")
//        })
//    }
//
//    // MARK: - Delete Functions
//    private func initiateDelete(at offsets: IndexSet) {
//        guard let index = offsets.first else { return }
//        breadcrumbToDelete = groupBreadcrumbs[index]
//        showDeleteConfirmation = true
//    }
//
//    private func confirmDelete() {
//        guard breadcrumbToDelete != nil else { return }
//        if let context = breadcrumbToDelete?.managedObjectContext {
//            context.delete(breadcrumbToDelete!)
//
//            do {
//                try context.save()
//            } catch {
//                print("Failed to delete breadcrumb: \(error.localizedDescription)")
//            }
//        }
//
//        breadcrumbToDelete = nil // Reset after deletion
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//    @State private var selectedTab: Tab = .home
//    @State private var breadcrumbToDelete: Breadcrumb? = nil // Declare mutable optional
//    @State private var showDeleteConfirmation = false
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            List {
//                ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                    Button(action: {
//                        navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                    }) {
//                        BreadcrumbTileView(breadcrumb: breadcrumb)
//                            .environmentObject(locationManager)
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//                .onDelete(perform: initiateDelete) // Add swipe-to-delete
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
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(groupBreadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: false,
//                showProfile: false
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(crmGroup?.groupName)
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
//        .alert("Delete Crumb?", isPresented: $showDeleteConfirmation, actions: {
//            Button("Delete", role: .destructive, action: confirmDelete)
//            Button("Cancel", role: .cancel, action: { breadcrumbToDelete = nil }) // Reset to nil
//        }, message: {
//            Text("Are you sure you want to delete this breadcrumb? This action cannot be undone.")
//        })
//    }
//
//    // MARK: - Delete Functions
//    private func initiateDelete(at offsets: IndexSet) {
//        guard let index = offsets.first else { return }
//        breadcrumbToDelete = groupBreadcrumbs[index] // Assign breadcrumb to delete
//        showDeleteConfirmation = true
//    }
//
//    private func confirmDelete() {
//        guard let breadcrumbToDelete = breadcrumbToDelete else { return }
//        let context = breadcrumbToDelete.managedObjectContext
//        context?.delete(breadcrumbToDelete)
//
//        do {
//            try context?.save() // Save changes to Core Data
//        } catch {
//            print("Failed to delete breadcrumb: \(error.localizedDescription)")
//        }
//
//        breadcrumbToDelete = nil // Reset after deletion
//    }
//}








//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel // Access your NavigationModel
//    @EnvironmentObject var locationManager: LocationManager // Pass LocationManager
//    @State private var selectedTab: Tab = .home // Track selected tab
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                VStack(spacing: 20) {
//                    ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                        Button(action: {
//                            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                        }) {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                                .environmentObject(locationManager)
//                        }
//                        .buttonStyle(PlainButtonStyle())
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
//                    // Navigate to GroupCrumbMapView with current group breadcrumbs
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(groupBreadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,        // Show Home button
//                showDropCrumb: true,  // Show Drop Crumb button
//                showMap: true,         // Show Map button
//                showGroups: false,     // Hide Groups button
//                showProfile: false     // Hide Profile button
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(crmGroup?.groupName)
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
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel // Access your NavigationModel
//    @State private var selectedTab: Tab = .home // Track selected tab
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // Scrollable List of Breadcrumbs
//            ScrollView {
//                VStack(spacing: 20) {
//                    ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                        Button(action: {
//                            // Navigate to BreadcrumbDetailView using NavigationModel
//                            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                        }) {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                        }
//                        .buttonStyle(PlainButtonStyle()) // Preserve original styling
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
//                    // Navigate to GroupCrumbMapView with current group breadcrumbs
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(groupBreadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,        // Show Home button
//                showDropCrumb: true,  // Show Drop Crumb button
//                showMap: true,         // Show Map button
//                showGroups: false,     // Hide Groups button
//                showProfile: false     // Hide Profile button
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(crmGroup?.groupName)
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
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel // Access your NavigationModel
//    @State private var selectedTab: Tab = .home // Track selected tab
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView {
//                VStack(spacing: 20) {
//                    ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                        Button(action: {
//                            // Navigate to BreadcrumbDetailView using NavigationModel
//                            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                        }) {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                        }
//                        .buttonStyle(PlainButtonStyle()) // Preserve original styling
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
//                    // Navigate to GroupCrumbMapView with current group breadcrumbs
//                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(groupBreadcrumbs)))
//                },
//                onGroups: {
//                    navigationModel.path.append(.groupsList)
//                },
//                onProfile: {
//                    navigationModel.path.append(.editProfile)
//                },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: false,
//                showProfile: false
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(crmGroup?.groupName)
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel // Access your NavigationModel
//
//    @State private var selectedTab: Tab = .home // State for the selected tab in BottomNavigationBar
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea() // Full-screen white background
//            
//            VStack(spacing: 0) {
//                ScrollView {
//                    VStack(spacing: 20) {
//                        ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                            Button(action: {
//                                // Navigate to BreadcrumbDetailView using NavigationModel
//                                navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                            }) {
//                                BreadcrumbTileView(breadcrumb: breadcrumb)
//                            }
//                            .buttonStyle(PlainButtonStyle()) // Preserve original styling
//                        }
//                    }
//                    .padding()
//                }
//
//                // Bottom Navigation Bar
//                BottomNavigationBar(
//                    selectedTab: $selectedTab,
//                    onHome: {
//                        navigationModel.path = [.dashboard]
//                    },
//                    onDropCrumb: {
//                        navigationModel.path.append(.addBreadcrumb)
//                    },
//                    onMap: {
//                        navigationModel.path.append(.breadcrumbMap(latitude: 0.0, longitude: 0.0, name: "Map View"))
//                    },
//                    onGroups: {
//                        navigationModel.path.append(.groupsList)
//                    },
//                    onProfile: {
//                        navigationModel.path.append(.editProfile)
//                    },
//                    showHome: true,        // Show Home button
//                    showDropCrumb: true,   // Show Drop Crumb button
//                    showMap: false,        // Hide Map button
//                    showGroups: true,      // Show Groups button
//                    showProfile: false      // Show Profile button
//                )
//                .frame(height: 60)
//            }
//        }
//        .navigationTitle(crmGroup?.groupName)
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel // Access your NavigationModel
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                    Button(action: {
//                        // Navigate to BreadcrumbDetailView using NavigationModel
//                        navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                    }) {
//                        BreadcrumbTileView(breadcrumb: breadcrumb)
//                    }
//                    .buttonStyle(PlainButtonStyle()) // Preserve original styling
//                }
//            }
//            .padding()
//        }
//        .navigationTitle(crmGroup?.groupName)
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//    let crmGroup?.groupName: String
//    @FetchRequest private var groupBreadcrumbs: FetchedResults<Breadcrumb>
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                ForEach(groupBreadcrumbs, id: \.self) { breadcrumb in
//                    BreadcrumbTileView(breadcrumb: breadcrumb)
//                }
//            }
//            .padding()
//        }
//        .navigationTitle(crmGroup?.groupName)
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//
//    let crmGroup?.groupName: String
//    @FetchRequest var groupBreadcrumbs: FetchedResults<Breadcrumb>
//    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        VStack {
//            // Scrollable Content
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Tile Container for Breadcrumbs
//                    TileContainerView(title: "", items: Array(groupBreadcrumbs)) { breadcrumb in
//                        Button(action: {
//                            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                        }) {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                        }
//                    }
//                }
//                .padding(.horizontal)
//            }
//            .background(Color.white) // ScrollView background
//            
//            Spacer() // Ensure content stays above any navigation bar or toolbar
//        }
//        .background(Color.white.ignoresSafeArea()) // Full-screen background
//        .navigationTitle(crmGroup?.groupName)
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text(crmGroup?.groupName)
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange")) // Dynamic navigation title color
//            }
//        }
//    }
//}


//import SwiftUI
//import CoreData
//
//struct GroupCrumbsView: View {
//
//    let crmGroup?.groupName: String
//    @FetchRequest var groupBreadcrumbs: FetchedResults<Breadcrumb>
//
//    init(crmGroup?.groupName: String) {
//        self.crmGroup?.groupName = crmGroup?.groupName
//        self._groupBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "crmGroup?.groupName == %@", crmGroup?.groupName)
//        )
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                // Tile Container for Breadcrumbs
//                TileContainerView(title: "Breadcrumbs in \(crmGroup?.groupName)", items: Array(groupBreadcrumbs)) { breadcrumb in
//                    NavigationLink(destination: BreadcrumbDetailView(breadcrumb: breadcrumb)) {
//                        BreadcrumbTileView(breadcrumb: breadcrumb)
//                    }
//                }
//            }
//            
//            .padding()
//        }
//        .background(.white).ignoresSafeArea() // Dynamic background color
//        .navigationTitle(crmGroup?.groupName)
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text(crmGroup?.groupName)
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange")) // Dynamic navigation title color
//            }
//        }
//    }
//
//}
//
//
