//
//  DashboardView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//

import SwiftUI
import CoreData

public struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var breadcrumbStore: BreadcrumbStore
    
    @FetchRequest(
        entity: Breadcrumb.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
    ) private var breadcrumbs: FetchedResults<Breadcrumb>
    
    private let recentDaysBack: Int = 90
    private let recentMaxPins: Int = 10

    var recentBreadcrumbs: [Breadcrumb] {

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -recentDaysBack,
            to: Date()
        ) ?? Date()

        return breadcrumbs
            .filter { crumb in

                // Do not show future Want to Go destinations
                guard !crumb.isWantToGo else {
                    return false
                }

                guard let d = crumb.dateDropped else {
                    return false
                }

                return d >= cutoff
            }
            .prefix(10)
            .map { $0 }
    }
    @Binding var selectedTab: Tab
    @State private var showImporter = false
    @State private var importErrorMessage: String?
    

    // MARK: - Constants
    private let unnamedPinName = "Unnamed Pin"

    // MARK: - Computed


    var favoriteBreadcrumbs: [Breadcrumb] {

        breadcrumbStore.favorites.filter { breadcrumb in

            !breadcrumb.isWantToGo
        }
    }
    
    var recentGroups: [String] {

        Array(
            Set(
                breadcrumbs
                    .filter { breadcrumb in

                        !breadcrumb.isWantToGo
                    }
                    .compactMap { breadcrumb in

                        breadcrumb.crmGroup?.groupName
                    }
            )
        )
        .sorted()
    }
    
    var unnamedBreadcrumbs: [Breadcrumb] {

        breadcrumbs.filter { crumb in

            // Do not show Want to Go destinations
            guard !crumb.isWantToGo else {
                return false
            }

            let name = (crumb.name ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            return name.caseInsensitiveCompare(
                unnamedPinName
            ) == .orderedSame
        }
    }
    
    var firstFiveUnnamedBreadcrumbs: [Breadcrumb] {
        Array(unnamedBreadcrumbs.prefix(5))
    }

    public var body: some View {

        GeometryReader { geometry in

            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            
                            SectionCard {
                                createRecentCrumbzSection()
                            }
                            
                            SectionCard {
                                createFavoriteCrumbzSection(
                                    availableWidth: geometry.size.width
                                )
                            }
                            SectionCard {
                                createGroupsSection()
                            }
                            
                            // If this section is already a "card" internally, you can remove the wrapper
                            // or keep it for consistent padding/styling.
                            SectionCard {
                                createUnnamedBreadcrumbsSection()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                    }
                    // MARK: - AdMob Banner
                    if !isLandscape {
                        WaymarXBannerView()
                    }
                    
                    // Bottom bar "docks" cleanly. Add a slight background to avoid floating-on-content look.
                    // Bottom Navigation Bar
                    BottomNavigationBar(
                        selectedTab: $selectedTab,
                        onHome: { navigationModel.path = [.dashboard] },
                        onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
                        onGroups: { navigationModel.path.append(.groupsList) },
                        onProfile: { navigationModel.path.append(.editProfile) },
                        onWantToGoList: { navigationModel.path.append(.wantToGoList) },
                        showHome: false,
                        showDropCrumb: true,
                        showMap: false,
                        showGroups: true,
                        showProfile: true,
                        showWantToGoList: true
                        
                    )
                    .frame(height: 70)
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color.black.opacity(0.08)),
                        alignment: .top
                    )
                }
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            configureNavigationBarAppearance()
            breadcrumbStore.breadcrumbs = Array(breadcrumbs)

            // (Optional) debug
            // for breadcrumb in breadcrumbs {
            //     print("Breadcrumb Name: \(breadcrumb.name ?? "Unnamed Pin"), Group: \(breadcrumb.crmGroup?.groupName ?? "No Group")")
            // }
        }
        .onChange(of: breadcrumbs.count) {
            withAnimation(.easeInOut(duration: 0.2)) {
                breadcrumbStore.breadcrumbs = Array(breadcrumbs)
            }
        }
        .toolbar {
            // Left: Home
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    navigationModel.path = [.content]
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Quick Drop")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
            }

            // Right: Actions
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    navigationModel.path.append(.allBreadcrumbs)
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("Dark Orange"))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showImporter = true
                    }
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showImporter) {
            DocumentPicker { pickedURL in
                let tempDirectory = FileManager.default.temporaryDirectory
                let localURL = tempDirectory.appendingPathComponent(pickedURL.lastPathComponent)

                do {
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        try FileManager.default.removeItem(at: localURL)
                    }
                    try FileManager.default.copyItem(at: pickedURL, to: localURL)
                    try ImportManager.importCrumbz(from: localURL, context: viewContext)
                    print("Import successful.")
                } catch {
                    importErrorMessage = "Import failed: \(error.localizedDescription)"
                    print(importErrorMessage!)
                }

                do {
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        try FileManager.default.removeItem(at: localURL)
                    }
                } catch {
                    print("Temp cleanup failed: \(error.localizedDescription)")
                }

                showImporter = false
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { _ in importErrorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "An unknown error occurred.")
        }
    }


    // MARK: - Reusable Card Wrapper
    private struct SectionCard<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
    }


    // MARK: - Sections
    
    private func createRecentCrumbzSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Button {
                    navigationModel.path.append(.recentBreadcrumbs)
                } label: {
                    HStack(spacing: 6) {
                        Text("Recent Pins")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 4)

            if recentBreadcrumbs.isEmpty {
                // Empty state inside the dashboard card
                HStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No recent pins")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)

                        Text("Get out and see something ☹️")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground)
                    .opacity(3.0)
                    .ignoresSafeArea())
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                SingleRowTileContainerView(title: "", items: recentBreadcrumbs) { breadcrumb in
                    Button {
                        navigationModel.pushBreadcrumbDetail(in: recentBreadcrumbs, selected: breadcrumb)
                    } label: {
                        RecentBreadcrumbTileView(
                            breadcrumb: breadcrumb,
                            isFavorite: favoriteBreadcrumbs.contains(where: { $0.objectID == breadcrumb.objectID })
                        )
                        .environmentObject(locationManager)
                        .padding(6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

            }
        }
    }
    
    private struct EmptyRecentPinsView: View {
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("Nothing Recent")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Get out and see something.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("The app can’t pin memories you don’t make.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(40)
        }
    }

    private func createFavoriteCrumbzSection(
        availableWidth: CGFloat
    ) -> some View {
        
        let horizontalPadding: CGFloat = 60
        let usableWidth = max(0, availableWidth - horizontalPadding)

        let preferredTileWidth: CGFloat = 110
        let tileSpacing: CGFloat = 10

        let columnCount = max(
            3,
            Int(
                (usableWidth + tileSpacing) /
                (preferredTileWidth + tileSpacing)
            )
        )

        let visibleFavoriteCount = columnCount * 2
        
        return VStack(alignment: .leading, spacing: 12) {
            
            Button {
                navigationModel.path.append(.favoritesBreadcrumbs)
            } label: {
                HStack(spacing: 6) {
                    Text("Favorite Pins")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .flexible(),
                        spacing: tileSpacing
                    ),
                    count: columnCount
                ),
                spacing: tileSpacing
            ) {
                ForEach(
                    favoriteBreadcrumbs.prefix(visibleFavoriteCount),
                    id: \.objectID
                ) { breadcrumb in

                    Button {
                        navigationModel.pushBreadcrumbDetail(in: favoriteBreadcrumbs, selected: breadcrumb)
                    } label: {
                        FavoriteCrumbTile(breadcrumb: breadcrumb)
                            .environmentObject(locationManager)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func createGroupsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {

            Button {
                navigationModel.path.append(.groupsList)
            } label: {
                HStack(spacing: 6) {
                    Text("Pin Groups")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                ForEach(recentGroups.prefix(6), id: \.self) { groupName in
                    
                    let groupPinCount = breadcrumbs.filter { breadcrumb in
                        breadcrumb.crmGroup?.groupName == groupName
                        && !breadcrumb.isWantToGo
                    }.count

                    Button {
                        navigationModel.path.append(.groupCrumbs(groupName: groupName))
                    } label: {
                        HStack {
                            Text(groupName)
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()
                            
                            Text("\(groupPinCount) Pin(s)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)                                                    }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func createUnnamedBreadcrumbsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header button = go to the Unnamed list screen (NOT a detail view)
            Button {
                navigationModel.path.append(
                    .unnamedBreadcrumbs)
            } label: {
                HStack(spacing: 6) {
                    Text("UnNamed Pins")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(unnamedBreadcrumbs.count)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if firstFiveUnnamedBreadcrumbs.isEmpty {
                Text("No unsaved pins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 10) {
                    ForEach(firstFiveUnnamedBreadcrumbs, id: \.objectID) { breadcrumb in
                        Button {
                            // Detail view with swipe within the current dashboard "first five" context
                            navigationModel.pushBreadcrumbDetail(in: unnamedBreadcrumbs, selected: breadcrumb)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(breadcrumb.name ?? unnamedPinName)
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(.primary)

                                Text(breadcrumb.dateDropped ?? Date(), style: .date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Nav bar appearance

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Dark Blue")
        appearance.titleTextAttributes = [.foregroundColor: UIColor(named: "Light Orange") ?? .white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}





//import SwiftUI
//import CoreData
//
//public struct DashboardView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//    @EnvironmentObject var breadcrumbStore: BreadcrumbStore
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
//    ) private var breadcrumbs: FetchedResults<Breadcrumb>
//
//    @Binding var selectedTab: Tab
//    @State private var showImporter = false
//    @State private var importErrorMessage: String?
//
//    // MARK: - Constants
//    private let unnamedPinName = "Unnamed Pin"
//
//    // MARK: - Computed
//    var recentBreadcrumbs: [Breadcrumb] {
//        Array(breadcrumbs.prefix(10))
//    }
//
//    var favoriteBreadcrumbs: [Breadcrumb] {
//        breadcrumbStore.favorites
//    }
//
//    var recentGroups: [String] {
//        Array(Set(breadcrumbs.compactMap { $0.crmGroup?.groupName })).sorted()
//    }
//
//    var unnamedBreadcrumbs: [Breadcrumb] {
//        breadcrumbs.filter { crumb in
//            let name = (crumb.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
//            return name.caseInsensitiveCompare(unnamedPinName) == .orderedSame
//        }
//    }
//
//    var firstFiveUnnamedBreadcrumbs: [Breadcrumb] {
//        Array(unnamedBreadcrumbs.prefix(5))
//    }
//
//    public var body: some View {
//        ZStack {
//            Color(.white).ignoresSafeArea()
//
//            VStack(spacing: 10) {
//                ScrollView {
//                    VStack(alignment: .leading, spacing: 15) {
//                        createRecentCrumbzSection()
//                            .padding(.vertical, 15)
//
//                        createFavoriteCrumbzSection()
//                            .padding(.vertical, 15)
//
//                        createGroupsSection()
//                            .padding(.vertical, 15)
//
//                        createUnnamedBreadcrumbsSection()
//                    }
//                    .padding()
//                }
//
//                Spacer()
//
//                BottomNavigationBar(
//                    selectedTab: $selectedTab,
//                    onHome: { navigationModel.path = [.dashboard] },
//                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                    onGroups: { navigationModel.path.append(.groupsList) },
//                    onProfile: { navigationModel.path.append(.editProfile) },
//                    showHome: false,
//                    showDropCrumb: true,
//                    showGroups: true,
//                    showProfile: true
//                )
//                .frame(height: 60)
//            }
//        }
//        .navigationTitle("Dashboard")
//        .navigationBarBackButtonHidden()
//        .navigationBarTitleDisplayMode(.inline)
//        .onAppear {
//            configureNavigationBarAppearance()
//            breadcrumbStore.breadcrumbs = Array(breadcrumbs)
//
//            // Debug print (optional)
//            for breadcrumb in breadcrumbs {
//                print("Breadcrumb Name: \(breadcrumb.name ?? "Unnamed Pin"), Group: \(breadcrumb.crmGroup?.groupName ?? "No Group")")
//            }
//        }
//        .onChange(of: breadcrumbs.count) {
//            breadcrumbStore.breadcrumbs = Array(breadcrumbs)
//        }
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: {
//                    navigationModel.path = [.content]
//                }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Home")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                HStack(spacing: 16) {
//                    Button(action: {
//                        navigationModel.path.append(.allBreadcrumbs)
//                    }) {
//                        Image(systemName: "list.bullet")
//                            .foregroundColor(Color("Dark Orange"))
//                    }
//
//                    Button(action: {
//                        showImporter = true
//                    }) {
//                        Image(systemName: "tray.and.arrow.down")
//                            .font(.system(size: 20))
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showImporter) {
//            DocumentPicker { pickedURL in
//                let tempDirectory = FileManager.default.temporaryDirectory
//                let localURL = tempDirectory.appendingPathComponent(pickedURL.lastPathComponent)
//
//                do {
//                    // Replace any existing temp copy
//                    if FileManager.default.fileExists(atPath: localURL.path) {
//                        try FileManager.default.removeItem(at: localURL)
//                    }
//
//                    // Copy to temp so we can access reliably
//                    try FileManager.default.copyItem(at: pickedURL, to: localURL)
//
//                    // Import from local copy
//                    try ImportManager.importCrumbz(from: localURL, context: viewContext)
//                    print("Import successful.")
//                } catch {
//                    importErrorMessage = "Import failed: \(error.localizedDescription)"
//                    print(importErrorMessage!)
//                }
//
//                // Cleanup temp file no matter what happened
//                do {
//                    if FileManager.default.fileExists(atPath: localURL.path) {
//                        try FileManager.default.removeItem(at: localURL)
//                    }
//                } catch {
//                    print("Temp cleanup failed: \(error.localizedDescription)")
//                }
//
//                showImporter = false
//            }
//        }
//        .alert("Import Error", isPresented: Binding(
//            get: { importErrorMessage != nil },
//            set: { _ in importErrorMessage = nil }
//        )) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text(importErrorMessage ?? "An unknown error occurred.")
//        }
//    }
//
//
//
//
//
//
//
