//
//  AllBreadcrumbsView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/17/24.
//
import SwiftUI
import CoreData

struct AllBreadcrumbsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel

    @FetchRequest(
        entity: Breadcrumb.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
    ) private var breadcrumbs: FetchedResults<Breadcrumb>

    @State private var filterOption: FilterOption = .dateAdded
    @State private var searchQuery: String = ""
    @State private var isSelecting = false
    @State private var selectedBreadcrumbs: Set<Breadcrumb> = []
    
    @State private var showShareSheet = false

    @State private var showDeleteAlert = false
    @State private var showMultiDeleteAlert = false

    // Group Import/Export UI
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showDocumentExporter = false
    @State private var showingImportPicker = false
    @State private var transferError: String?
    @State private var breadcrumbToDelete: Breadcrumb?

    // MARK: - Filter Options
    enum FilterOption: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case favorites = "Favorites"
        case group = "Group"
        case name = "Name"
        var id: String { rawValue }
    }

    // MARK: - Filtering
    var filteredBreadcrumbs: [Breadcrumb] {

        var results: [Breadcrumb]

        switch filterOption {

        case .dateAdded:

            results = regularBreadcrumbs.sorted {
                ($0.dateDropped ?? Date())
                >
                ($1.dateDropped ?? Date())
            }

        case .favorites:

            results = regularBreadcrumbs.filter {
                $0.isFavorite
            }

        case .group:

            results = regularBreadcrumbs.sorted {
                ($0.crmGroup?.groupName ?? "")
                <
                ($1.crmGroup?.groupName ?? "")
            }

        case .name:

            results = regularBreadcrumbs.sorted {
                ($0.name ?? "")
                <
                ($1.name ?? "")
            }
        }

        let trimmed = searchQuery
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            return results
        }

        let q = trimmed.lowercased()

        return results.filter { breadcrumb in

            (breadcrumb.name ?? "")
                .lowercased()
                .contains(q)

            ||

            (breadcrumb.crmGroup?.groupName ?? "")
                .lowercased()
                .contains(q)

            ||

            formattedDate(
                breadcrumb.dateDropped
            )
            .lowercased()
            .contains(q)
        }
    }
    
    private var regularBreadcrumbs: [Breadcrumb] {
        breadcrumbs.filter { !$0.isWantToGo }
    }
    
    // MARK: - Body
    var body: some View {

        GeometryReader { geometry in
            
            let isLandscape =
            geometry.size.width > geometry.size.height
            VStack(spacing: 0) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        VStack(spacing: 10) {
                            searchBar
                            
                            List {
                                ForEach(filteredBreadcrumbs, id: \.self) { breadcrumb in
                                    row(for: breadcrumb)
                                        .listRowBackground(Color(.systemBackground))
                                }
                                .onDelete(perform: showDeleteConfirmation)
                            }
                            .listStyle(.plain)
                        }
                        .padding(.top, 10)
                    }
                
                // MARK: - AdMob Banner
                if !isLandscape {
                    WaymarXBannerView()
                }
                
                // Bottom Navigation Bar (unchanged)
                BottomNavigationBar(
                    selectedTab: .constant(.home),
                    onHome: { navigationModel.path = [.dashboard] },
                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
                    onMap: { navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(filteredBreadcrumbs))) },
                    onGroups: { navigationModel.path.append(.groupsList) },
                    onProfile: { navigationModel.path.append(.editProfile) },
                    showHome: true,
                    showDropCrumb: true,
                    showMap: true,
                    showGroups: true,
                    showProfile: true
                )
                .frame(height: 60)
            }
        }
        .navigationTitle(isSelecting ? "Select Pins" : "All Pins")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            configureNavigationBarAppearance()
        }
        .toolbar {
            // Left: Back (Dashboard style)
            ToolbarItem(placement: .navigationBarLeading) {
                if isSelecting {
                    Button {
                        withAnimation {
                            isSelecting = false
                            selectedBreadcrumbs.removeAll()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                    }
                } else {
                    Button {
                        navigationModel.pop()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                    }
                }
            }

            // Right: Actions (Dashboard style)
            ToolbarItemGroup(placement: .navigationBarTrailing) {

                if isSelecting {
                    // Delete selected (only when something selected)
                    if !selectedBreadcrumbs.isEmpty {
                        Button {
                            showMultiDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }

                    // Done selecting
                    Button {
                        withAnimation {
                            isSelecting = false
                            selectedBreadcrumbs.removeAll()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                } else {
                    // Enter select mode
                    Button {
                        withAnimation {
                            isSelecting = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                // Filter menu (orange icon like Dashboard list icon)
                Menu {
                    Picker("Filter", selection: $filterOption) {
                        ForEach(FilterOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("Dark Orange"))
                }
                .disabled(isSelecting)
                Button {
                    ExportManager.exportAllBreadcrumbs(
                        regularBreadcrumbs
                    ) { url in
                        guard let url = url else {
                            transferError = "Failed to export all Pins."
                            return
                        }

                        exportURL = url
                        showDocumentExporter = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .disabled(isSelecting)
                Button {
                    showingImportPicker = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .disabled(isSelecting)
            }
        }
        .alert("Delete Pin?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let crumb = breadcrumbToDelete {
                    deleteBreadcrumb(crumb)
                }
            }
        } message: {
            Text("Are you sure you want to delete this Pin?")
        }
        .alert("Delete Selected Pins?", isPresented: $showMultiDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedBreadcrumbs()
            }
        } message: {
            Text("Are you sure you want to delete the selected Pins?")
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportURL = exportURL {
                ShareSheet(
                    activityItems: [exportURL]
                )
            }
        }
        .sheet(isPresented: $showDocumentExporter) {
            if let exportURL = exportURL {
                DocumentExporter(
                    url: exportURL
                ) {
                    try? FileManager.default.removeItem(
                        at: exportURL
                    )

                    self.exportURL = nil
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
        .alert("Import/Export", isPresented: Binding(get: { transferError != nil }, set: { if !$0 { transferError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transferError ?? "")
        }
//        Button {
//            ExportManager.cleanupOldAllPinsExports()
//
//            ExportManager.exportAllBreadcrumbs(
//                Array(breadcrumbs)
//            ) { url in
//
//                guard let url = url else {
//                    transferError = "Failed to export all Pins."
//                    return
//                }
//
//                exportURL = url
//                showDocumentExporter = true
//            }
//
//        } label: {
//            Image(systemName: "square.and.arrow.up.on.square")
//        }

    }

    // MARK: - Components

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search...", text: $searchQuery)
                .foregroundStyle(.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func row(for breadcrumb: Breadcrumb) -> some View {
        HStack(spacing: 10) {
            if isSelecting {
                Button {
                    toggleSelection(for: breadcrumb)
                } label: {
                    Image(systemName: selectedBreadcrumbs.contains(breadcrumb) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedBreadcrumbs.contains(breadcrumb) ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                if isSelecting {
                    toggleSelection(for: breadcrumb)
                } else {
                    let ids = filteredBreadcrumbs.map { $0.objectID }
                    let startIndex = ids.firstIndex(of: breadcrumb.objectID) ?? 0
                    navigationModel.path.append(.breadcrumbDetailIDs(objectIDs: ids, startIndex: startIndex))
                }
            } label: {
                BreadcrumbTileView(breadcrumb: breadcrumb)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .contextMenu {
            if let group = breadcrumb.value(forKey: "crmGroup") as? CrmGroup {
                Button {
                    ExportManager.exportGroup(group) { url in
                        DispatchQueue.main.async {
                            exportURL = url
                            if url != nil {
                                showShareSheet = true
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
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func showDeleteConfirmation(at offsets: IndexSet) {
        if let index = offsets.first {
            breadcrumbToDelete = filteredBreadcrumbs[index]
            showDeleteAlert = true
        }
    }

    private func deleteBreadcrumb(_ breadcrumb: Breadcrumb) {
        withAnimation {
            viewContext.delete(breadcrumb)
            saveContext()
        }
    }

    private func deleteSelectedBreadcrumbs() {
        withAnimation {
            selectedBreadcrumbs.forEach(viewContext.delete)
            saveContext()
            selectedBreadcrumbs.removeAll()
            isSelecting = false
        }
    }

    private func toggleSelection(for breadcrumb: Breadcrumb) {
        if selectedBreadcrumbs.contains(breadcrumb) {
            selectedBreadcrumbs.remove(breadcrumb)
        } else {
            selectedBreadcrumbs.insert(breadcrumb)
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Nav bar appearance (Dashboard style)

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Dark Blue") ?? UIColor.systemBlue

        // Match Dashboard: title uses Light Orange (fallback to white)
        let titleColor = UIColor(named: "Light Orange") ?? UIColor.white
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Force bar button items away from that unreadable blue tint
        UINavigationBar.appearance().tintColor = .white
    }
}






//022626 Before Group Crumb Export
//
//import SwiftUI
//import CoreData
//
//struct AllBreadcrumbsView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    @State private var filterOption: FilterOption = .dateAdded
//    @State private var searchQuery: String = ""
//    @State private var isSelecting = false
//    @State private var selectedBreadcrumbs: Set<Breadcrumb> = []
//
//    @State private var showDeleteAlert = false
//    @State private var showMultiDeleteAlert = false
//    @State private var breadcrumbToDelete: Breadcrumb?
//
//    // MARK: - Filter Options
//    enum FilterOption: String, CaseIterable, Identifiable {
//        case dateAdded = "Date Added"
//        case favorites = "Favorites"
//        case group = "Group"
//        case name = "Name"
//        var id: String { rawValue }
//    }
//
//    // MARK: - Filtering
//    var filteredBreadcrumbs: [Breadcrumb] {
//        var results: [Breadcrumb]
//
//        switch filterOption {
//        case .dateAdded:
//            results = breadcrumbs.sorted { ($0.dateDropped ?? Date()) > ($1.dateDropped ?? Date()) }
//        case .favorites:
//            results = breadcrumbs.filter { $0.isFavorite }
//        case .group:
//            results = breadcrumbs.sorted { ($0.crmGroup?.groupName ?? "") < ($1.crmGroup?.groupName ?? "") }
//        case .name:
//            results = breadcrumbs.sorted { ($0.name ?? "") < ($1.name ?? "") }
//        }
//
//        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmed.isEmpty else { return results }
//
//        let q = trimmed.lowercased()
//        return results.filter { breadcrumb in
//            (breadcrumb.name ?? "").lowercased().contains(q) ||
//            (breadcrumb.crmGroup?.groupName ?? "").lowercased().contains(q) ||
//            formattedDate(breadcrumb.dateDropped).lowercased().contains(q)
//        }
//    }
//
//    // MARK: - Body
//    var body: some View {
//        VStack(spacing: 0) {
//            Color(.systemBackground)
//                .ignoresSafeArea()
//                .overlay(alignment: .top) {
//                    VStack(spacing: 10) {
//                        searchBar
//
//                        List {
//                            ForEach(filteredBreadcrumbs, id: \.self) { breadcrumb in
//                                row(for: breadcrumb)
//                                    .listRowBackground(Color(.systemBackground))
//                            }
//                            .onDelete(perform: showDeleteConfirmation)
//                        }
//                        .listStyle(.plain)
//                    }
//                    .padding(.top, 10)
//                }
//
//            // Bottom Navigation Bar (unchanged)
//            BottomNavigationBar(
//                selectedTab: .constant(.home),
//                onHome: { navigationModel.path = [.dashboard] },
//                onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                onMap: { navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(filteredBreadcrumbs))) },
//                onGroups: { navigationModel.path.append(.groupsList) },
//                onProfile: { navigationModel.path.append(.editProfile) },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: true,
//                showProfile: true
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(isSelecting ? "Select Pins" : "All Pins")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .onAppear {
//            configureNavigationBarAppearance()
//        }
//        .toolbar {
//            // Left: Back (Dashboard style)
//            ToolbarItem(placement: .navigationBarLeading) {
//                if isSelecting {
//                    Button {
//                        withAnimation {
//                            isSelecting = false
//                            selectedBreadcrumbs.removeAll()
//                        }
//                    } label: {
//                        HStack(spacing: 6) {
//                            Image(systemName: "xmark")
//                                .font(.system(size: 16, weight: .semibold))
//                            Text("Cancel")
//                                .font(.system(size: 16, weight: .semibold))
//                        }
//                        .foregroundStyle(.white)
//                    }
//                } else {
//                    Button {
//                        navigationModel.pop()
//                    } label: {
//                        HStack(spacing: 6) {
//                            Image(systemName: "chevron.left")
//                                .font(.system(size: 16, weight: .semibold))
//                            Text("Back")
//                                .font(.system(size: 16, weight: .semibold))
//                        }
//                        .foregroundStyle(.white)
//                    }
//                }
//            }
//
//            // Right: Actions (Dashboard style)
//            ToolbarItemGroup(placement: .navigationBarTrailing) {
//
//                if isSelecting {
//                    // Delete selected (only when something selected)
//                    if !selectedBreadcrumbs.isEmpty {
//                        Button {
//                            showMultiDeleteAlert = true
//                        } label: {
//                            Image(systemName: "trash")
//                                .font(.system(size: 18, weight: .semibold))
//                                .foregroundStyle(.red)
//                        }
//                    }
//
//                    // Done selecting
//                    Button {
//                        withAnimation {
//                            isSelecting = false
//                            selectedBreadcrumbs.removeAll()
//                        }
//                    } label: {
//                        Image(systemName: "checkmark")
//                            .font(.system(size: 18, weight: .semibold))
//                            .foregroundStyle(.white)
//                    }
//
//                } else {
//                    // Enter select mode
//                    Button {
//                        withAnimation {
//                            isSelecting = true
//                        }
//                    } label: {
//                        Image(systemName: "pencil")
//                            .font(.system(size: 18, weight: .semibold))
//                            .foregroundStyle(.white)
//                    }
//                }
//
//                // Filter menu (orange icon like Dashboard list icon)
//                Menu {
//                    Picker("Filter", selection: $filterOption) {
//                        ForEach(FilterOption.allCases) { option in
//                            Text(option.rawValue).tag(option)
//                        }
//                    }
//                } label: {
//                    Image(systemName: "line.horizontal.3.decrease.circle")
//                        .font(.system(size: 18, weight: .semibold))
//                        .foregroundStyle(Color("Dark Orange"))
//                }
//                .disabled(isSelecting)
//            }
//        }
//        .alert("Delete Pin?", isPresented: $showDeleteAlert) {
//            Button("Cancel", role: .cancel) {}
//            Button("Delete", role: .destructive) {
//                if let crumb = breadcrumbToDelete {
//                    deleteBreadcrumb(crumb)
//                }
//            }
//        } message: {
//            Text("Are you sure you want to delete this Pin?")
//        }
//        .alert("Delete Selected Pins?", isPresented: $showMultiDeleteAlert) {
//            Button("Cancel", role: .cancel) {}
//            Button("Delete", role: .destructive) {
//                deleteSelectedBreadcrumbs()
//            }
//        } message: {
//            Text("Are you sure you want to delete the selected Pins?")
//        }
//    }
//
//    // MARK: - Components
//
//    private var searchBar: some View {
//        HStack(spacing: 10) {
//            Image(systemName: "magnifyingglass")
//                .foregroundStyle(.secondary)
//
//            TextField("Search...", text: $searchQuery)
//                .foregroundStyle(.primary)
//                .textInputAutocapitalization(.never)
//                .autocorrectionDisabled(true)
//
//            if !searchQuery.isEmpty {
//                Button {
//                    searchQuery = ""
//                } label: {
//                    Image(systemName: "xmark.circle.fill")
//                        .foregroundStyle(.secondary)
//                }
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 10)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color(.secondarySystemBackground))
//        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
//        )
//        .padding(.horizontal)
//    }
//
//    private func row(for breadcrumb: Breadcrumb) -> some View {
//        HStack(spacing: 10) {
//            if isSelecting {
//                Button {
//                    toggleSelection(for: breadcrumb)
//                } label: {
//                    Image(systemName: selectedBreadcrumbs.contains(breadcrumb) ? "checkmark.circle.fill" : "circle")
//                        .font(.title3)
//                        .foregroundStyle(selectedBreadcrumbs.contains(breadcrumb) ? .green : .secondary)
//                }
//                .buttonStyle(.plain)
//            }
//
//            Button {
//                if isSelecting {
//                    toggleSelection(for: breadcrumb)
//                } else {
//                    let ids = filteredBreadcrumbs.map { $0.objectID }
//                    let startIndex = ids.firstIndex(of: breadcrumb.objectID) ?? 0
//                    navigationModel.path.append(.breadcrumbDetailIDs(objectIDs: ids, startIndex: startIndex))
//                }
//            } label: {
//                BreadcrumbTileView(breadcrumb: breadcrumb)
//            }
//            .buttonStyle(.plain)
//        }
//        .contentShape(Rectangle())
//        .contextMenu {
//            Button(role: .destructive) {
//                breadcrumbToDelete = breadcrumb
//                showDeleteAlert = true
//            } label: {
//                Label("Delete", systemImage: "trash")
//            }
//        }
//    }
//
//    // MARK: - Helpers
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date else { return "" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        return formatter.string(from: date)
//    }
//
//    private func showDeleteConfirmation(at offsets: IndexSet) {
//        if let index = offsets.first {
//            breadcrumbToDelete = filteredBreadcrumbs[index]
//            showDeleteAlert = true
//        }
//    }
//
//    private func deleteBreadcrumb(_ breadcrumb: Breadcrumb) {
//        withAnimation {
//            viewContext.delete(breadcrumb)
//            saveContext()
//        }
//    }
//
//    private func deleteSelectedBreadcrumbs() {
//        withAnimation {
//            selectedBreadcrumbs.forEach(viewContext.delete)
//            saveContext()
//            selectedBreadcrumbs.removeAll()
//            isSelecting = false
//        }
//    }
//
//    private func toggleSelection(for breadcrumb: Breadcrumb) {
//        if selectedBreadcrumbs.contains(breadcrumb) {
//            selectedBreadcrumbs.remove(breadcrumb)
//        } else {
//            selectedBreadcrumbs.insert(breadcrumb)
//        }
//    }
//
//    private func saveContext() {
//        do {
//            try viewContext.save()
//        } catch {
//            print("Save error: \(error.localizedDescription)")
//        }
//    }
//
//    // MARK: - Nav bar appearance (Dashboard style)
//
//    private func configureNavigationBarAppearance() {
//        let appearance = UINavigationBarAppearance()
//        appearance.configureWithOpaqueBackground()
//        appearance.backgroundColor = UIColor(named: "Dark Blue") ?? UIColor.systemBlue
//
//        // Match Dashboard: title uses Light Orange (fallback to white)
//        let titleColor = UIColor(named: "Light Orange") ?? UIColor.white
//        appearance.titleTextAttributes = [.foregroundColor: titleColor]
//        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
//
//        UINavigationBar.appearance().standardAppearance = appearance
//        UINavigationBar.appearance().scrollEdgeAppearance = appearance
//        UINavigationBar.appearance().compactAppearance = appearance
//
//        // Force bar button items away from that unreadable blue tint
//        UINavigationBar.appearance().tintColor = .white
//    }
//}




//import SwiftUI
//import CoreData
//
//struct AllBreadcrumbsView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    @State private var filterOption: FilterOption = .dateAdded
//    @State private var searchQuery: String = ""
//    @State private var isSelecting = false
//    @State private var selectedBreadcrumbs: Set<Breadcrumb> = []
//    
//    @State private var showDeleteAlert = false
//    @State private var showMultiDeleteAlert = false
//    @State private var breadcrumbToDelete: Breadcrumb?
//
//    // Filter Options
//    enum FilterOption: String, CaseIterable, Identifiable {
//        case dateAdded = "Date Added"
//        case favorites = "Favorites"
//        case group = "Group"
//        case name = "Name"
//
//        var id: String { self.rawValue }
//    }
//
//    var filteredBreadcrumbs: [Breadcrumb] {
//        var results: [Breadcrumb]
//        
//        switch filterOption {
//        case .dateAdded:
//            results = breadcrumbs.sorted { ($0.dateDropped ?? Date()) > ($1.dateDropped ?? Date()) }
//        case .favorites:
//            results = breadcrumbs.filter { $0.isFavorite }
//        case .group:
//            results = breadcrumbs.sorted { ($0.crmGroup?.groupName ?? "") < ($1.crmGroup?.groupName ?? "") }
//        case .name:
//            results = breadcrumbs.sorted { ($0.name ?? "") < ($1.name ?? "") }
//        }
//
//        if searchQuery.isEmpty {
//            return results
//        } else {
//            return results.filter { breadcrumb in
//                let query = searchQuery.lowercased()
//                return (breadcrumb.name ?? "").lowercased().contains(query) ||
//                       (breadcrumb.crmGroup?.groupName ?? "").lowercased().contains(query) ||
//                       formattedDate(breadcrumb.dateDropped).lowercased().contains(query)
//            }
//        }
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // Search Bar
//            TextField("Search...", text: $searchQuery)
//                .padding(10)
//                .background(.white)
//                .foregroundColor(Color("Light Orange").opacity(0.9))
//                .cornerRadius(10)
//                .frame(height: 45)
//                .padding(.horizontal)
//                .padding(.top, 10)
//
//            // List of Breadcrumbs
//            List {
//                ForEach(filteredBreadcrumbs, id: \.self) { breadcrumb in
//                    HStack {
//                        if isSelecting {
//                            Button(action: {
//                                toggleSelection(for: breadcrumb)
//                            }) {
//                                Image(systemName: selectedBreadcrumbs.contains(breadcrumb) ? "checkmark.circle.fill" : "circle")
//                                    .foregroundColor(selectedBreadcrumbs.contains(breadcrumb) ? .green : .gray)
//                                    .font(.title2)
//                            }
//                        }
//
//                        Button(action: {
//                            if isSelecting {
//                                toggleSelection(for: breadcrumb)
//                            } else {
//                                let ids = filteredBreadcrumbs.map { $0.objectID }
//                                let startIndex = ids.firstIndex(of: breadcrumb.objectID) ?? 0
//                                navigationModel.path.append(.breadcrumbDetailIDs(objectIDs: ids, startIndex: startIndex))
//                            }
//                        }) {
//                            BreadcrumbTileView(breadcrumb: breadcrumb)
//                        }
//                        .buttonStyle(PlainButtonStyle()) // Preserve original styling
//                    }
//                    .contextMenu {
//                        Button(role: .destructive) {
//                            breadcrumbToDelete = breadcrumb
//                            showDeleteAlert = true
//                        } label: {
//                            Label("Delete", systemImage: "trash")
//                        }
//                    }
//                }
//                .onDelete(perform: showDeleteConfirmation)
//            }
//            .listStyle(PlainListStyle())
//
//            // Bottom Navigation Bar
//            BottomNavigationBar(
//                selectedTab: .constant(.home),
//                onHome: { navigationModel.path = [.dashboard] },
//                onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                onMap: { navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: Array(filteredBreadcrumbs))) },
//                onGroups: { navigationModel.path.append(.groupsList) },
//                onProfile: { navigationModel.path.append(.editProfile) },
//                showHome: true,
//                showDropCrumb: true,
//                showMap: true,
//                showGroups: true,
//                showProfile: true
//            )
//            .frame(height: 60)
//        }
//        .navigationTitle(isSelecting ? "Select Pins" : "All Pins")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                if isSelecting {
//                    Button("Cancel") {
//                        withAnimation {
//                            isSelecting = false
//                            selectedBreadcrumbs.removeAll()
//                        }
//                    }
//                } else {
//                    Button(action: { navigationModel.pop() }) {
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
//                if isSelecting {
//                    if !selectedBreadcrumbs.isEmpty {
//                        Button(action: {
//                            showMultiDeleteAlert = true
//                        }) {
//                            Image(systemName: "trash")
//                                .foregroundColor(.red)
//                        }
//                    }
//                } else {
//                    Button("Edit") {
//                        withAnimation {
//                            isSelecting = true
//                        }
//                    }
//                    .foregroundColor(.white)
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Menu {
//                    Picker("Filter", selection: $filterOption) {
//                        ForEach(FilterOption.allCases) { option in
//                            Text(option.rawValue).tag(option)
//                        }
//                    }
//                } label: {
//                    Image(systemName: "line.horizontal.3.decrease.circle")
//                        .foregroundColor(Color("Dark Orange"))
//                        .font(.title2)
//                }
//                .disabled(isSelecting)
//            }
//        }
//        .alert("Delete Pin?", isPresented: $showDeleteAlert, actions: {
//            Button("Cancel", role: .cancel) {}
//            Button("Delete", role: .destructive) {
//                if let crumb = breadcrumbToDelete {
//                    deleteBreadcrumb(crumb)
//                }
//            }
//        }, message: {
//            Text("Are you sure you want to delete this Pin?")
//        })
//        .alert("Delete Selected Pins?", isPresented: $showMultiDeleteAlert, actions: {
//            Button("Cancel", role: .cancel) {}
//            Button("Delete", role: .destructive) {
//                deleteSelectedBreadcrumbs()
//            }
//        }, message: {
//            Text("Are you sure you want to delete the selected Pins?")
//        })
//    }
//
//    // MARK: - Helper Functions
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        return formatter.string(from: date)
//    }
//
//    private func showDeleteConfirmation(at offsets: IndexSet) {
//        if let index = offsets.first {
//            breadcrumbToDelete = filteredBreadcrumbs[index]
//            showDeleteAlert = true
//        }
//    }
//
//    private func deleteBreadcrumb(_ breadcrumb: Breadcrumb) {
//        withAnimation {
//            viewContext.delete(breadcrumb)
//            saveContext()
//        }
//    }
//
//    private func deleteSelectedBreadcrumbs() {
//        withAnimation {
//            for breadcrumb in selectedBreadcrumbs {
//                viewContext.delete(breadcrumb)
//            }
//            saveContext()
//            selectedBreadcrumbs.removeAll()
//            isSelecting = false
//        }
//    }
//
//    private func toggleSelection(for breadcrumb: Breadcrumb) {
//        if selectedBreadcrumbs.contains(breadcrumb) {
//            selectedBreadcrumbs.remove(breadcrumb)
//        } else {
//            selectedBreadcrumbs.insert(breadcrumb)
//        }
//    }
//
//    private func saveContext() {
//        do {
//            try viewContext.save()
//        } catch {
//            print("Error saving context: \(error.localizedDescription)")
//        }
//    }
//}


