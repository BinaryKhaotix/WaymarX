//
//  UnnamedPinsView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/16/26.
//
import SwiftUI
import CoreData

public struct UnnamedPinsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var locationManager: LocationManager
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Breadcrumb.dateDropped,
                ascending: false
            )
        ],
        animation: .default
    )
    private var fetchedBreadcrumbs: FetchedResults<Breadcrumb>
    
    // Group Import/Export UI
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingImportPicker = false
    @State private var transferError: String?
    @State private var selectedTab: Tab = .home
    @State private var isSelecting = false
    @State private var selectedBreadcrumbs: Set<NSManagedObjectID> = []
    @State private var showDeleteAlert = false
    
    private var regularBreadcrumbs: [Breadcrumb] {
        
        let unnamedPinName = "Unnamed Pin"
        
        return fetchedBreadcrumbs.filter { breadcrumb in
            
            guard !breadcrumb.isWantToGo else {
                return false
            }
            
            let name = (breadcrumb.name ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            
            return name.caseInsensitiveCompare(
                unnamedPinName
            ) == .orderedSame
        }
    }
    
    public var body: some View {

        GeometryReader { geometry in

            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    ScrollView {
                        
                        VStack(alignment: .leading, spacing: 12) {
                            
                            //                        Text("UnNamed Pins")
                            //                            .font(.title2)
                            //                            .bold()
                            //                            .foregroundColor(Color("Dark Blue"))
                            //                            .padding(.horizontal)
                            
                            Text("\(regularBreadcrumbs.count) Pin(s)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: 10),
                                    count: 3
                                ),
                                spacing: 10
                            ) {
                                
                                ForEach(regularBreadcrumbs, id: \.objectID) { breadcrumb in
                                    
                                    Button {
                                        
                                        if isSelecting {
                                            
                                            if selectedBreadcrumbs.contains(breadcrumb.objectID) {
                                                selectedBreadcrumbs.remove(breadcrumb.objectID)
                                            } else {
                                                selectedBreadcrumbs.insert(breadcrumb.objectID)
                                            }
                                            
                                        } else {
                                            
                                            navigationModel.pushBreadcrumbDetail(
                                                in: regularBreadcrumbs,
                                                selected: breadcrumb
                                            )
                                        }
                                        
                                    } label: {
                                        
                                        ZStack(alignment: .topTrailing) {
                                            
                                            UnnamedPinTile(
                                                breadcrumb: breadcrumb
                                            )
                                            .environmentObject(locationManager)
                                            
                                            if isSelecting {
                                                
                                                Image(
                                                    systemName:
                                                        selectedBreadcrumbs.contains(breadcrumb.objectID)
                                                    ? "checkmark.circle.fill"
                                                    : "circle"
                                                )
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(
                                                    selectedBreadcrumbs.contains(breadcrumb.objectID)
                                                    ? Color.accentColor
                                                    : Color.white
                                                )
                                                .background(
                                                    Circle()
                                                        .fill(Color.black.opacity(0.25))
                                                )
                                                .padding(8)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    .contextMenu {
                                        
                                        if !isSelecting {
                                            
                                            if let group =
                                                breadcrumb.value(
                                                    forKey: "crmGroup"
                                                ) as? CrmGroup {
                                                
                                                Button {
                                                    
                                                    ExportManager.exportGroup(
                                                        group
                                                    ) { url in
                                                        
                                                        DispatchQueue.main.async {
                                                            
                                                            exportURL = url
                                                            
                                                            if url != nil {
                                                                showingShareSheet = true
                                                            } else {
                                                                transferError =
                                                                "Export failed."
                                                            }
                                                        }
                                                    }
                                                    
                                                } label: {
                                                    
                                                    Label(
                                                        "Export Group",
                                                        systemImage:
                                                            "square.and.arrow.up"
                                                    )
                                                }
                                            }
                                            
                                            Button(
                                                role: .destructive
                                            ) {
                                                
                                                selectedBreadcrumbs = [
                                                    breadcrumb.objectID
                                                ]
                                                
                                                showDeleteAlert = true
                                                
                                            } label: {
                                                
                                                Label(
                                                    "Delete Pin",
                                                    systemImage: "trash"
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        .padding(.vertical)
                    }
                    
                    // MARK: - AdMob Banner
                    
                    if !isLandscape {
                        WaymarXBannerView()
                    }
                    
                    // MARK: - Bottom Navigation
                    
                    BottomNavigationBar(
                        selectedTab: $selectedTab,
                        
                        onHome: {
                            navigationModel.path = [.dashboard]
                        },
                        
                        onDropCrumb: {
                            navigationModel.path.append(
                                .addBreadcrumb
                            )
                        },
                        
                        onGroups: {
                            navigationModel.path.append(
                                .groupsList
                            )
                        },
                        
                        onProfile: {
                            navigationModel.path.append(
                                .editProfile
                            )
                        },
                        
                        onWantToGoList: {
                            navigationModel.path.append(
                                .wantToGoList
                            )
                        },
                        
                        showHome: true,
                        showDropCrumb: true,
                        showMap: false,
                        showGroups: true,
                        showProfile: true,
                        showWantToGoList: true
                    )
                    .frame(height: 70)
                    .background(
                        Color(.systemBackground)
                    )
                    .overlay(
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(
                                Color.black.opacity(0.08)
                            ),
                        
                        alignment: .top
                    )
                }
            }
        }
        .onAppear{
            ContextualTipManager.shared.showIfNeeded(
                .unsavedPins
            )
        }
        .navigationTitle("UnNamed Pins")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        
        .toolbar {
            
            ToolbarItem(
                placement: .navigationBarLeading
            ) {
                
                Button {
                    
                    navigationModel.pop()
                    
                } label: {
                    
                    HStack {
                        
                        Image(
                            systemName: "chevron.left"
                        )
                        .foregroundColor(.white)
                        
                        Text("Back")
                            .foregroundColor(.white)
                    }
                }
            }
            
            ToolbarItemGroup(
                placement: .navigationBarTrailing
            ) {
                
                if isSelecting {
                    
                    if !selectedBreadcrumbs.isEmpty {
                        
                        Button {
                            
                            showDeleteAlert = true
                            
                        } label: {
                            
                            Image(systemName: "trash")
                                .font(
                                    .system(
                                        size: 18,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Button {
                        
                        withAnimation {
                            isSelecting = false
                            selectedBreadcrumbs.removeAll()
                        }
                        
                    } label: {
                        
                        Image(systemName: "checkmark")
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)
                    }
                    
                } else {
                    
                    Button {
                        
                        withAnimation {
                            isSelecting = true
                        }
                        
                    } label: {
                        
                        Image(systemName: "checkmark.circle")
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        
                        showingImportPicker = true
                        
                    } label: {
                        
                        Image(
                            systemName:
                                "square.and.arrow.down.on.square"
                        )
                        .foregroundStyle(.white)
                    }
                }
            }
        }
        
        .sheet(
            isPresented: $showingImportPicker
        ) {
            
            DocumentPicker { pickedURL in
                
                do {
                    
                    try ImportManager.importGroup(
                        from: pickedURL,
                        context: viewContext
                    )
                    
                } catch {
                    
                    transferError =
                    error.localizedDescription
                }
            }
        }
        
        .sheet(
            isPresented: $showingShareSheet
        ) {
            
            if let exportURL {
                
                ShareSheet(
                    activityItems: [exportURL]
                )
            }
        }
        .alert(
            selectedBreadcrumbs.count == 1
            ? "Delete Pin?"
            : "Delete \(selectedBreadcrumbs.count) Pins?",
            isPresented: $showDeleteAlert
        ) {
            
            Button(
                "Cancel",
                role: .cancel
            ) {
                // Do nothing
            }
            
            Button(
                "Delete",
                role: .destructive
            ) {
                deleteSelectedBreadcrumbs()
            }
            
        } message: {
            
            if selectedBreadcrumbs.count == 1 {
                
                Text(
                    "This pin will be permanently deleted."
                )
                
            } else {
                
                Text(
                    "These \(selectedBreadcrumbs.count) pins will be permanently deleted."
                )
            }
        }
        .alert(
            "Group Transfer",
            
            isPresented: Binding(
                
                get: {
                    transferError != nil
                },
                
                set: {
                    if !$0 {
                        transferError = nil
                    }
                }
            )
        ) {
            
            Button(
                "OK",
                role: .cancel
            ) {}
            
        } message: {
            
            Text(
                transferError ?? ""
            )
        }
    }
    private func deleteSelectedBreadcrumbs() {
        
        let objectsToDelete = regularBreadcrumbs.filter {
            selectedBreadcrumbs.contains($0.objectID)
        }
        
        withAnimation {
            
            for breadcrumb in objectsToDelete {
                viewContext.delete(breadcrumb)
            }
            
            do {
                
                try viewContext.save()
                
                selectedBreadcrumbs.removeAll()
                isSelecting = false
                
            } catch {
                
                print(
                    "Failed to delete unnamed pin(s): \(error.localizedDescription)"
                )
                
                transferError =
                "Unable to delete the selected pin(s). \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Tile for Unnamed Pins (own style, heart only if favorite)
private struct UnnamedPinTile: View {
    @EnvironmentObject var locationManager: LocationManager
    let breadcrumb: Breadcrumb

    private var displayName: String {
        let name = (breadcrumb.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed Pin" : name
    }

    private var isFavorite: Bool {
        // ✅ CHANGE THIS KEY if your Core Data field is not named "isFavorite"
        // Example alternatives:
        // (breadcrumb.value(forKey: "favorite") as? Bool) ?? false
        // (breadcrumb.value(forKey: "isFav") as? Bool) ?? false
        (breadcrumb.value(forKey: "isFavorite") as? Bool) ?? false
    }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Background Image
            if let photoFileName = breadcrumb.photoURL,
               let image = loadImage(from: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipped()
            } else {
                Color.gray
                    .opacity(0.15)
                    .frame(width: 110, height: 110)
            }

            // Readability overlay
            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Top badges row
            HStack(spacing: 6) {
//                Text("UNSAVED")
//                    .font(.system(size: 10, weight: .bold))
//                    //.font(.caption)
//                    .fontWeight(.bold)
//                    .foregroundStyle(Color("Dark Blue"))
//                    .padding(.horizontal, 8)
//                    .padding(.vertical, 5)
//                    .background(Color("Dark Orange").opacity(0.92))
//                    .clipShape(Capsule())

                Spacer(minLength: 0)

                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Circle())
                }
            }
            .padding(8)

            // Bottom name overlay
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(displayName)
                        .font(.system(size: 12, weight: .bold))
                        //.font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }
                .padding(8)
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 5)
    }
}









// 022626 before group crumb export/import modifications
//
//import SwiftUI
//import CoreData
//
//public struct UnnamedPinsView: View {
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//
//    public let breadcrumbs: [Breadcrumb]
//
//    public var body: some View {
//        ZStack {
//            Color(.white).ignoresSafeArea()
//
//            ScrollView {
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("Unsaved Pins")
//                        .font(.title2)
//                        .bold()
//                        .foregroundColor(Color("Dark Blue"))
//                        .padding(.horizontal)
//
//                    Text("\(breadcrumbs.count) Pin(s)")
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                        .padding(.horizontal)
//
//                    LazyVGrid(
//                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
//                        spacing: 10
//                    ) {
//                        ForEach(breadcrumbs, id: \.objectID) { breadcrumb in
//                            Button {
//                                navigationModel.pushBreadcrumbDetail(in: breadcrumbs, selected: breadcrumb)
//                            } label: {
//                                UnnamedPinTile(breadcrumb: breadcrumb)
//                                    .environmentObject(locationManager)
//                            }
//                            .buttonStyle(.plain)
//                        }
//                    }
//                    .padding(.horizontal)
//                    .padding(.top, 8)
//                }
//                .padding(.vertical)
//            }
//        }
//        .navigationTitle("Unsaved Pins")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button {
//                    navigationModel.pop()
//                } label: {
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

// MARK: - Image Loader (local helper)
//private func loadImage(from fileName: String) -> UIImage? {
//    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
//        .appendingPathComponent(fileName)
//
//    guard let imageURL = url,
//          let data = try? Data(contentsOf: imageURL),
//          let image = UIImage(data: data) else {
//        return nil
//    }
//
//    return image
//}


// MARK: - Tile for Unnamed Pins (own style, heart only if favorite)
//private struct UnnamedPinTile: View {
//    @EnvironmentObject var locationManager: LocationManager
//    let breadcrumb: Breadcrumb
//
//    private var displayName: String {
//        let name = (breadcrumb.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
//        return name.isEmpty ? "Unnamed Pin" : name
//    }
//
//    private var isFavorite: Bool {
//        // ✅ CHANGE THIS KEY if your Core Data field is not named "isFavorite"
//        // Example alternatives:
//        // (breadcrumb.value(forKey: "favorite") as? Bool) ?? false
//        // (breadcrumb.value(forKey: "isFav") as? Bool) ?? false
//        (breadcrumb.value(forKey: "isFavorite") as? Bool) ?? false
//    }
//
//    var body: some View {
//        ZStack(alignment: .topLeading) {
//
//            // Background Image
//            if let photoFileName = breadcrumb.photoURL,
//               let image = loadImage(from: photoFileName) {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 110, height: 110)
//                    .clipped()
//            } else {
//                Color.gray
//                    .opacity(0.15)
//                    .frame(width: 110, height: 110)
//            }
//
//            // Readability overlay
//            LinearGradient(
//                colors: [Color.black.opacity(0.05), Color.black.opacity(0.65)],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//
//            // Top badges row
//            HStack(spacing: 6) {
//                Text("UNSAVED")
//                    .font(.caption2)
//                    .fontWeight(.bold)
//                    .foregroundStyle(Color("Dark Blue"))
//                    .padding(.horizontal, 8)
//                    .padding(.vertical, 5)
//                    .background(Color("Dark Orange").opacity(0.92))
//                    .clipShape(Capsule())
//
//                Spacer(minLength: 0)
//
//                if isFavorite {
//                    Image(systemName: "heart.fill")
//                        .font(.system(size: 13, weight: .bold))
//                        .foregroundStyle(.red)
//                        .padding(6)
//                        .background(Color.white.opacity(0.85))
//                        .clipShape(Circle())
//                }
//            }
//            .padding(8)
//
//            // Bottom name overlay
//            VStack {
//                Spacer()
//                HStack(spacing: 6) {
//                    Image(systemName: "mappin.and.ellipse")
//                        .font(.system(size: 14, weight: .semibold))
//                        .foregroundStyle(.white)
//
//                    Text(displayName)
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundStyle(.white)
//                        .lineLimit(2)
//
//                    Spacer(minLength: 0)
//                }
//                .padding(8)
//            }
//        }
//        .frame(width: 110, height: 110)
//        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
//        .overlay(
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .stroke(Color.black.opacity(0.08), lineWidth: 1)
//        )
//        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 5)
//    }
//}

