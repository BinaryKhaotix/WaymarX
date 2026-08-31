//
//  BreadcrumbDetailView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//
import SwiftUI
import MapKit
import CoreData

// BreadcrumbDetailView.swift

struct BreadcrumbDetailView: View {

    // MARK: - Mode
    private enum Mode {
        case single(Breadcrumb)
        case paged(objectIDs: [NSManagedObjectID], startIndex: Int)
    }

    private let mode: Mode

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var currentIndex: Int = 0
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showFullScreenImage = false
    @State private var selectedTab: Tab = .home

    // Swipe tuning
    private let swipeThreshold: CGFloat = 70
    private let swipeDominanceRatio: CGFloat = 1.2

    // MARK: - Initializers

    /// Used all over the app (no paging).
    init(breadcrumb: Breadcrumb) {
        self.mode = .single(breadcrumb)
    }

    /// Used when you want swipe paging in a specific context (AllBreadcrumbs, group, favorites, etc.)
    init(objectIDs: [NSManagedObjectID], startIndex: Int) {
        self.mode = .paged(objectIDs: objectIDs, startIndex: startIndex)
        _currentIndex = State(initialValue: max(0, min(startIndex, max(0, objectIDs.count - 1))))
    }

    // MARK: - Helpers

    private var pagedIDs: [NSManagedObjectID] {
        switch mode {
        case .single:
            return []
        case .paged(let ids, _):
            return ids
        }
    }

    private var isPagingEnabled: Bool {
        pagedIDs.count > 1
    }

    private func resolveBreadcrumb() -> Breadcrumb? {
        switch mode {
        case .single(let crumb):
            return crumb
        case .paged(let ids, _):
            guard !ids.isEmpty else { return nil }
            do {
                return try viewContext.existingObject(with: ids[currentIndex]) as? Breadcrumb
            } catch {
                return nil
            }
        }
    }

    // MARK: - Body

    var body: some View {
        let crumb = resolveBreadcrumb()

        return Group {
            if let breadcrumb = crumb {
                BreadcrumbDetailContentView(
                    breadcrumb: breadcrumb,
                    exportURL: $exportURL,
                    showingShareSheet: $showingShareSheet,
                    showFullScreenImage: $showFullScreenImage,
                    selectedTab: $selectedTab,
                    onHome: { navigationModel.path = [.dashboard] },
                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
                    onMap: { navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb)) },
                    onGroups: { navigationModel.path.append(.groupsList) },
                    onProfile: { navigationModel.path.append(.editProfile) },
                    onNavigate: { navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb)) },
                    onEdit: { navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb)) },
                    onExport: { exportBreadcrumb(breadcrumb) },
                    onToggleFavorite: { toggleFavoriteStatus(breadcrumb) },
                    onPromote: { Task { await WantToGoArrivalManager .shared .markAsVisited( breadcrumb ) } },
                    onBack: { navigationModel.pop() }
                )
                .id(breadcrumb.objectID)
            } else {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Text("Pin not available")
                            .font(.title2)
                            .foregroundStyle(.primary)

                        Text("It may have been deleted or is unavailable.")
                            .foregroundStyle(.secondary)

                        Button("Back") { navigationModel.pop() }
                            .foregroundStyle(Color("Light Orange"))
                    }
                    .padding()
                }
            }
        }
        // ✅ DO NOT use highPriorityGesture here. It steals the drag from ScrollView.
        // ✅ simultaneousGesture allows ScrollView to keep scrolling while we still detect strong horizontal swipes.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onEnded { value in
                    guard isPagingEnabled else { return }

                    let dx = value.translation.width
                    let dy = value.translation.height

                    // Strongly horizontal
                    guard abs(dx) > abs(dy) * swipeDominanceRatio else { return }
                    guard abs(dx) > swipeThreshold else { return }

                    if dx < 0 {
                        goNext()
                    } else {
                        goPrevious()
                    }
                }
        )
    }

    // MARK: - Paging

    private func goNext() {
        guard isPagingEnabled else { return }
        guard currentIndex < pagedIDs.count - 1 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.18)) {
            currentIndex += 1
        }
    }

    private func goPrevious() {
        guard isPagingEnabled else { return }
        guard currentIndex > 0 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.18)) {
            currentIndex -= 1
        }
    }

    // MARK: - Actions (operate on a specific crumb)

    private func exportBreadcrumb(_ breadcrumb: Breadcrumb) {
        ExportManager.exportSingleCrumb(breadcrumb) { url in
            if let url = url {
                exportURL = url
                showingShareSheet = true
            } else {
                print("Export failed.")
            }
        }
    }

    private func toggleFavoriteStatus(_ breadcrumb: Breadcrumb) {
        breadcrumb.isFavorite.toggle()
        do {
            try viewContext.save()
        } catch {
            print("Failed to update favorite status: \(error.localizedDescription)")
        }
    }
}

// MARK: - Content View (same UI, no environment-object juggling needed)

private struct BreadcrumbDetailContentView: View {
    @ObservedObject var breadcrumb: Breadcrumb

    @Binding var exportURL: URL?
    @Binding var showingShareSheet: Bool
    @Binding var showFullScreenImage: Bool
    @Binding var selectedTab: Tab

    let onHome: () -> Void
    let onDropCrumb: () -> Void
    let onMap: () -> Void
    let onGroups: () -> Void
    let onProfile: () -> Void
    let onNavigate: () -> Void
    let onEdit: () -> Void
    let onExport: () -> Void
    let onToggleFavorite: () -> Void
    let onPromote: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 10) {
                        BreadcrumbHeaderView(breadcrumb: breadcrumb)
                        BreadcrumbImageView(breadcrumb: breadcrumb, showFullScreenImage: $showFullScreenImage)
                        if breadcrumb.isWantToGo { Button( action: onPromote ) { Label( "Promote Pin", systemImage: "arrow.up.circle.fill" ) .font( .system( size: 17, weight: .semibold ) ) .frame( maxWidth: .infinity ) .padding(.vertical, 12) .background( Color("Dark Blue") ) .foregroundStyle( Color("Light Orange") ) .clipShape( RoundedRectangle( cornerRadius: 14, style: .continuous ) ) } .buttonStyle(.plain) .padding(.horizontal, 20) }
                        LocationDateView(breadcrumb: breadcrumb)
                        NotesView(breadcrumb: breadcrumb)

                        // ✅ iOS 18 map + iOS 17 fallback
                        if #available(iOS 18, *) {
                            CrumbMapView_iOS18(nonIdCrumb: NonIdentifiableBreadcrumb(breadcrumb: breadcrumb))
                        } else {
                            CrumbMapView_Legacy(
                                coordinate: CLLocationCoordinate2D(latitude: breadcrumb.latitude,
                                                                   longitude: breadcrumb.longitude)
                            )
                        }

                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal)
                }

                BottomNavigationBar(
                    selectedTab: $selectedTab,
                    onHome: onHome,
                    onDropCrumb: onDropCrumb,
                    onMap: onMap,
                    onGroups: onGroups,
                    onProfile: onProfile,
                    onNavigate: onNavigate,
                    showHome: true,
                    showDropCrumb: true,
                    showMap: true,
                    showGroups: true,
                    showProfile: false,
                    showNavigate: true
                )
                .frame(height: 60)
            }
        }
        .navigationTitle("Pin Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)

        // ✅ TOOLBAR LEFT UNCHANGED PER REQUEST
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 20))
                        .foregroundColor(Color("Light Orange"))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onToggleFavorite) {
                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
                }
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                        Text("Back")
                            .foregroundColor(.white)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(Color(.white))
                }
            }
        }
        .sheet(isPresented: $showFullScreenImage) {
            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
                FullScreenImageView(image: image)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func loadImage(from fileName: String?) -> UIImage? {
        guard let fileName = fileName else { return nil }
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

private struct BreadcrumbHeaderView: View {
    let breadcrumb: Breadcrumb

    var body: some View {
        VStack {
            Text(breadcrumb.name ?? "Unnamed Pin")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            HStack {
                Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BreadcrumbImageView: View {
    let breadcrumb: Breadcrumb
    @Binding var showFullScreenImage: Bool

    var body: some View {
        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
            Button(action: { showFullScreenImage.toggle() }) {
                let imageAspectRatio = image.size.width / image.size.height
                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
                let buttonHeight = maxImageWidth / imageAspectRatio

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: maxImageWidth, height: buttonHeight)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 300)
                .overlay(
                    Text("No Image Available")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                )
                .background(Color(.secondarySystemBackground))
                .cornerRadius(30)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
        }
    }

    private func loadImage(from fileName: String?) -> UIImage? {
        guard let fileName = fileName else { return nil }
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

private struct LocationDateView: View {
    let breadcrumb: Breadcrumb

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center, spacing: 10) {
                Text("LOCATION")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                Text(formatAddress(from: breadcrumb))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()
                .frame(height: 100)

            VStack(alignment: .center, spacing: 10) {
                Text("DATE/TIME")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                Text(formattedDate(breadcrumb.dateDropped))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: UIScreen.main.bounds.width - 40)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
        let streetAddress = breadcrumb.streetAddress ?? "No Address"
        let city = breadcrumb.city ?? "No City"
        let state = breadcrumb.state ?? "No State"
        let zipCode = breadcrumb.zipCode ?? "No Zip"
        return "\(streetAddress), \(city), \(state) \(zipCode)"
    }
}

private struct NotesView: View {
    let breadcrumb: Breadcrumb

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Text("Notes:")
                .font(.headline)
                .foregroundStyle(Color("Light Orange"))

            Text(breadcrumb.note ?? "No Notes")
                .foregroundStyle(.primary)
                .padding(.bottom)
        }
        .padding(.horizontal)
    }
}

// MARK: - iOS 18 Map (your existing approach)

@available(iOS 18, *)
private struct NonIdentifiableBreadcrumb {
    let breadcrumb: Breadcrumb
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: breadcrumb.latitude,
                               longitude: breadcrumb.longitude)
    }
}

@available(iOS 18, *)
private struct DummyAnnotation: Identifiable {
    let id = UUID()
}

@available(iOS 18, *)
private struct CrumbMapView_iOS18: View {
    let nonIdCrumb: NonIdentifiableBreadcrumb

    private var region: Binding<MKCoordinateRegion> {
        .constant(
            MKCoordinateRegion(
                center: nonIdCrumb.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    var body: some View {
        Map(
            coordinateRegion: region,
            interactionModes: .all,
            showsUserLocation: false,
            userTrackingMode: .constant(.none),
            annotationItems: [DummyAnnotation()]
        ) { _ in
            MapMarker(coordinate: nonIdCrumb.coordinate, tint: .red)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

// MARK: - iOS 17 and below Map fallback

private struct CrumbMapView_Legacy: View {
    let coordinate: CLLocationCoordinate2D

    private var region: Binding<MKCoordinateRegion> {
        .constant(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    var body: some View {
        Map(coordinateRegion: region, annotationItems: [LegacyPin(coordinate: coordinate)]) { pin in
            MapMarker(coordinate: pin.coordinate, tint: .red)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private struct LegacyPin: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }
}



//import SwiftUI
//import MapKit
//import CoreData
//
//// BreadcrumbDetailView.swift
//
//struct BreadcrumbDetailView: View {
//
//    // MARK: - Mode
//    private enum Mode {
//        case single(Breadcrumb)
//        case paged(objectIDs: [NSManagedObjectID], startIndex: Int)
//    }
//
//    private let mode: Mode
//
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    @State private var currentIndex: Int = 0
//    @State private var exportURL: URL?
//    @State private var showingShareSheet = false
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home
//
//    // Swipe tuning
//    private let swipeThreshold: CGFloat = 70
//    private let swipeDominanceRatio: CGFloat = 1.2
//
//    // MARK: - Initializers
//
//    /// Used all over the app (no paging).
//    init(breadcrumb: Breadcrumb) {
//        self.mode = .single(breadcrumb)
//    }
//
//    /// Used when you want swipe paging in a specific context (AllBreadcrumbs, group, favorites, etc.)
//    init(objectIDs: [NSManagedObjectID], startIndex: Int) {
//        self.mode = .paged(objectIDs: objectIDs, startIndex: startIndex)
//        _currentIndex = State(initialValue: max(0, min(startIndex, max(0, objectIDs.count - 1))))
//    }
//
//    // MARK: - Helpers
//
//    private var pagedIDs: [NSManagedObjectID] {
//        switch mode {
//        case .single:
//            return []
//        case .paged(let ids, _):
//            return ids
//        }
//    }
//
//    private var isPagingEnabled: Bool {
//        pagedIDs.count > 1
//    }
//
//    private func resolveBreadcrumb() -> Breadcrumb? {
//        switch mode {
//        case .single(let crumb):
//            return crumb
//        case .paged(let ids, _):
//            guard !ids.isEmpty else { return nil }
//            do {
//                return try viewContext.existingObject(with: ids[currentIndex]) as? Breadcrumb
//            } catch {
//                return nil
//            }
//        }
//    }
//
//    // MARK: - Body
//
//    var body: some View {
//        let crumb = resolveBreadcrumb()
//
//        return Group {
//            if let breadcrumb = crumb {
//                BreadcrumbDetailContentView(
//                    breadcrumb: breadcrumb,
//                    exportURL: $exportURL,
//                    showingShareSheet: $showingShareSheet,
//                    showFullScreenImage: $showFullScreenImage,
//                    selectedTab: $selectedTab,
//                    onHome: { navigationModel.path = [.dashboard] },
//                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                    onMap: { navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb)) },
//                    onGroups: { navigationModel.path.append(.groupsList) },
//                    onProfile: { navigationModel.path.append(.editProfile) },
//                    onNavigate: { navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb)) },
//                    onEdit: { navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb)) },
//                    onExport: { exportBreadcrumb(breadcrumb) },
//                    onToggleFavorite: { toggleFavoriteStatus(breadcrumb) },
//                    onBack: { navigationModel.pop() }
//                )
//                .id(breadcrumb.objectID)
//            } else {
//                ZStack {
//                    Color.white.ignoresSafeArea()
//                    VStack(spacing: 12) {
//                        Text("Pin not available")
//                            .font(.title2)
//                            .foregroundColor(Color("Dark Blue"))
//                        Text("It may have been deleted or is unavailable.")
//                            .foregroundColor(.gray)
//                        Button("Back") { navigationModel.pop() }
//                            .foregroundColor(Color("Light Orange"))
//                    }
//                    .padding()
//                }
//            }
//        }
//        // ✅ DO NOT use highPriorityGesture here. It steals the drag from ScrollView.
//        // ✅ simultaneousGesture allows ScrollView to keep scrolling while we still detect strong horizontal swipes.
//        .simultaneousGesture(
//            DragGesture(minimumDistance: 12, coordinateSpace: .local)
//                .onEnded { value in
//                    guard isPagingEnabled else { return }
//
//                    let dx = value.translation.width
//                    let dy = value.translation.height
//
//                    // Strongly horizontal
//                    guard abs(dx) > abs(dy) * swipeDominanceRatio else { return }
//                    guard abs(dx) > swipeThreshold else { return }
//
//                    if dx < 0 {
//                        goNext()
//                    } else {
//                        goPrevious()
//                    }
//                }
//        )
//    }
//
//    // MARK: - Paging
//
//    private func goNext() {
//        guard isPagingEnabled else { return }
//        guard currentIndex < pagedIDs.count - 1 else { return }
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//        withAnimation(.easeInOut(duration: 0.18)) {
//            currentIndex += 1
//        }
//    }
//
//    private func goPrevious() {
//        guard isPagingEnabled else { return }
//        guard currentIndex > 0 else { return }
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//        withAnimation(.easeInOut(duration: 0.18)) {
//            currentIndex -= 1
//        }
//    }
//
//    // MARK: - Actions (operate on a specific crumb)
//
//    private func exportBreadcrumb(_ breadcrumb: Breadcrumb) {
//        ExportManager.exportSingleCrumb(breadcrumb) { url in
//            if let url = url {
//                exportURL = url
//                showingShareSheet = true
//            } else {
//                print("Export failed.")
//            }
//        }
//    }
//
//    private func toggleFavoriteStatus(_ breadcrumb: Breadcrumb) {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//}
//
//// MARK: - Content View (same UI, no environment-object juggling needed)
//
//private struct BreadcrumbDetailContentView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//
//    @Binding var exportURL: URL?
//    @Binding var showingShareSheet: Bool
//    @Binding var showFullScreenImage: Bool
//    @Binding var selectedTab: Tab
//
//    let onHome: () -> Void
//    let onDropCrumb: () -> Void
//    let onMap: () -> Void
//    let onGroups: () -> Void
//    let onProfile: () -> Void
//    let onNavigate: () -> Void
//    let onEdit: () -> Void
//    let onExport: () -> Void
//    let onToggleFavorite: () -> Void
//    let onBack: () -> Void
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea()
//
//            VStack(spacing: 0) {
//                ScrollView {
//                    VStack(spacing: 10) {
//                        BreadcrumbHeaderView(breadcrumb: breadcrumb)
//                        BreadcrumbImageView(breadcrumb: breadcrumb, showFullScreenImage: $showFullScreenImage)
//                        LocationDateView(breadcrumb: breadcrumb)
//                        NotesView(breadcrumb: breadcrumb)
//
//                        // ✅ iOS 18 map + iOS 17 fallback
//                        if #available(iOS 18, *) {
//                            CrumbMapView_iOS18(nonIdCrumb: NonIdentifiableBreadcrumb(breadcrumb: breadcrumb))
//                        } else {
//                            CrumbMapView_Legacy(
//                                coordinate: CLLocationCoordinate2D(latitude: breadcrumb.latitude,
//                                                                   longitude: breadcrumb.longitude)
//                            )
//                        }
//
//                        Spacer().frame(height: 80)
//                    }
//                    .padding(.horizontal)
//                }
//
//                BottomNavigationBar(
//                    selectedTab: $selectedTab,
//                    onHome: onHome,
//                    onDropCrumb: onDropCrumb,
//                    onMap: onMap,
//                    onGroups: onGroups,
//                    onProfile: onProfile,
//                    onNavigate: onNavigate,
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false,
//                    showNavigate: true
//                )
//                .frame(height: 60)
//            }
//        }
//        .navigationTitle("Pin Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: onEdit) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: onToggleFavorite) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: onBack) {
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
//                Button(action: onExport) {
//                    Image(systemName: "square.and.arrow.up")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color(.white))
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//        .sheet(isPresented: $showingShareSheet) {
//            if let url = exportURL {
//                ShareSheet(activityItems: [url])
//            }
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//private struct BreadcrumbHeaderView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack {
//            Text(breadcrumb.name ?? "Unnamed Pin")
//                .font(.largeTitle)
//                .bold()
//                .foregroundColor(Color("Dark Blue"))
//                .multilineTextAlignment(.center)
//                .padding(.top, 20)
//            HStack {
//                Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Blue"))
//            }
//        }
//    }
//}
//
//private struct BreadcrumbImageView: View {
//    let breadcrumb: Breadcrumb
//    @Binding var showFullScreenImage: Bool
//
//    var body: some View {
//        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//            Button(action: { showFullScreenImage.toggle() }) {
//                let imageAspectRatio = image.size.width / image.size.height
//                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                let buttonHeight = maxImageWidth / imageAspectRatio
//
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: maxImageWidth, height: buttonHeight)
//                    .background(Color.white)
//                    .cornerRadius(30)
//                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                    .padding(.horizontal, 20)
//            }
//            .padding(.bottom, 20)
//        } else {
//            Rectangle()
//                .fill(Color.gray.opacity(0.2))
//                .frame(height: 300)
//                .overlay(
//                    Text("No Image Available")
//                        .font(.headline)
//                        .foregroundColor(.gray)
//                )
//                .background(Color.white)
//                .cornerRadius(30)
//                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                .padding(.horizontal, 20)
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//private struct LocationDateView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        HStack(alignment: .top) {
//            VStack(alignment: .center, spacing: 10) {
//                Text("LOCATION")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formatAddress(from: breadcrumb))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//                HStack {
//                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                        .font(.system(size: 12))
//                        .foregroundColor(Color("Dark Blue"))
//                        .multilineTextAlignment(.center)
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//
//            Divider()
//                .frame(height: 100)
//                .bold()
//                .background(Color("Dark Blue"))
//
//            VStack(alignment: .center, spacing: 10) {
//                Text("DATE/TIME")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formattedDate(breadcrumb.dateDropped))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//        }
//        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//        .background(Color.white)
//        .cornerRadius(30)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
//        let streetAddress = breadcrumb.streetAddress ?? "No Address"
//        let city = breadcrumb.city ?? "No City"
//        let state = breadcrumb.state ?? "No State"
//        let zipCode = breadcrumb.zipCode ?? "No Zip"
//        return "\(streetAddress), \(city), \(state) \(zipCode)"
//    }
//}
//
//private struct NotesView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack(alignment: .center, spacing: 5) {
//            Text("Notes:")
//                .font(.headline)
//                .foregroundColor(Color("Light Orange"))
//            Text(breadcrumb.note ?? "No Notes")
//                .foregroundColor(Color("Dark Blue"))
//                .padding(.bottom)
//        }
//        .padding(.horizontal)
//    }
//}
//
//// MARK: - iOS 18 Map (your existing approach)
//
//@available(iOS 18, *)
//private struct NonIdentifiableBreadcrumb {
//    let breadcrumb: Breadcrumb
//    var coordinate: CLLocationCoordinate2D {
//        CLLocationCoordinate2D(latitude: breadcrumb.latitude,
//                               longitude: breadcrumb.longitude)
//    }
//}
//
//@available(iOS 18, *)
//private struct DummyAnnotation: Identifiable {
//    let id = UUID()
//}
//
//@available(iOS 18, *)
//private struct CrumbMapView_iOS18: View {
//    let nonIdCrumb: NonIdentifiableBreadcrumb
//
//    private var region: Binding<MKCoordinateRegion> {
//        .constant(
//            MKCoordinateRegion(
//                center: nonIdCrumb.coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//            )
//        )
//    }
//
//    var body: some View {
//        Map(
//            coordinateRegion: region,
//            interactionModes: .all,
//            showsUserLocation: false,
//            userTrackingMode: .constant(.none),
//            annotationItems: [DummyAnnotation()]
//        ) { _ in
//            MapMarker(coordinate: nonIdCrumb.coordinate, tint: .red)
//        }
//        .frame(height: 200)
//        .frame(maxWidth: .infinity)
//        .cornerRadius(15)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//        .padding(.horizontal, 20)
//    }
//}
//
//// MARK: - iOS 17 and below Map fallback
//
//private struct CrumbMapView_Legacy: View {
//    let coordinate: CLLocationCoordinate2D
//
//    private var region: Binding<MKCoordinateRegion> {
//        .constant(
//            MKCoordinateRegion(
//                center: coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//            )
//        )
//    }
//
//    var body: some View {
//        Map(coordinateRegion: region, annotationItems: [LegacyPin(coordinate: coordinate)]) { pin in
//            MapMarker(coordinate: pin.coordinate, tint: .red)
//        }
//        .frame(height: 200)
//        .frame(maxWidth: .infinity)
//        .cornerRadius(15)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//        .padding(.horizontal, 20)
//    }
//
//    private struct LegacyPin: Identifiable {
//        let id = UUID()
//        let coordinate: CLLocationCoordinate2D
//    }
//}



//import SwiftUI
//import MapKit
//import CoreData
//
//// BreadcrumbDetailView.swift
//
//struct BreadcrumbDetailView: View {
//
//    // MARK: - Mode
//    private enum Mode {
//        case single(Breadcrumb)
//        case paged(objectIDs: [NSManagedObjectID], startIndex: Int)
//    }
//
//    private let mode: Mode
//
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    @State private var currentIndex: Int = 0
//    @State private var exportURL: URL?
//    @State private var showingShareSheet = false
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home
//
//    // Swipe tuning
//    private let swipeThreshold: CGFloat = 70
//    private let swipeDominanceRatio: CGFloat = 1.2
//
//    // MARK: - Initializers
//
//    /// Used all over the app (no paging).
//    init(breadcrumb: Breadcrumb) {
//        self.mode = .single(breadcrumb)
//    }
//
//    /// Used when you want swipe paging in a specific context (AllBreadcrumbs, group, favorites, etc.)
//    init(objectIDs: [NSManagedObjectID], startIndex: Int) {
//        self.mode = .paged(objectIDs: objectIDs, startIndex: startIndex)
//        _currentIndex = State(initialValue: max(0, min(startIndex, max(0, objectIDs.count - 1))))
//    }
//
//    // MARK: - Helpers
//
//    private var pagedIDs: [NSManagedObjectID] {
//        switch mode {
//        case .single:
//            return []
//        case .paged(let ids, _):
//            return ids
//        }
//    }
//
//    private var isPagingEnabled: Bool {
//        pagedIDs.count > 1
//    }
//
//    private func resolveBreadcrumb() -> Breadcrumb? {
//        switch mode {
//        case .single(let crumb):
//            return crumb
//        case .paged(let ids, _):
//            guard !ids.isEmpty else { return nil }
//            do {
//                return try viewContext.existingObject(with: ids[currentIndex]) as? Breadcrumb
//            } catch {
//                return nil
//            }
//        }
//    }
//
//    // MARK: - Body
//
//    var body: some View {
//        let crumb = resolveBreadcrumb()
//
//        return Group {
//            if let breadcrumb = crumb {
//                BreadcrumbDetailContentView(
//                    breadcrumb: breadcrumb,
//                    exportURL: $exportURL,
//                    showingShareSheet: $showingShareSheet,
//                    showFullScreenImage: $showFullScreenImage,
//                    selectedTab: $selectedTab,
//                    onHome: { navigationModel.path = [.dashboard] },
//                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                    onMap: { navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb)) },
//                    onGroups: { navigationModel.path.append(.groupsList) },
//                    onProfile: { navigationModel.path.append(.editProfile) },
//                    onNavigate: { navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb)) },
//                    onEdit: { navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb)) },
//                    onExport: { exportBreadcrumb(breadcrumb) },
//                    onToggleFavorite: { toggleFavoriteStatus(breadcrumb) },
//                    onBack: { navigationModel.pop() }
//                )
//                .id(breadcrumb.objectID)
//            } else {
//                ZStack {
//                    Color.white.ignoresSafeArea()
//                    VStack(spacing: 12) {
//                        Text("Pin not available")
//                            .font(.title2)
//                            .foregroundColor(Color("Dark Blue"))
//                        Text("It may have been deleted or is unavailable.")
//                            .foregroundColor(.gray)
//                        Button("Back") { navigationModel.pop() }
//                            .foregroundColor(Color("Light Orange"))
//                    }
//                    .padding()
//                }
//            }
//        }
//        .highPriorityGesture(
//            DragGesture(minimumDistance: 10, coordinateSpace: .local)
//                .onEnded { value in
//                    guard isPagingEnabled else { return }
//
//                    let dx = value.translation.width
//                    let dy = value.translation.height
//
//                    // Strongly horizontal
//                    guard abs(dx) > abs(dy) * swipeDominanceRatio else { return }
//                    guard abs(dx) > swipeThreshold else { return }
//
//                    if dx < 0 {
//                        goNext()
//                    } else {
//                        goPrevious()
//                    }
//                }
//        )
//    }
//
//    // MARK: - Paging
//
//    private func goNext() {
//        guard isPagingEnabled else { return }
//        guard currentIndex < pagedIDs.count - 1 else { return }
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//        withAnimation(.easeInOut(duration: 0.18)) {
//            currentIndex += 1
//        }
//    }
//
//    private func goPrevious() {
//        guard isPagingEnabled else { return }
//        guard currentIndex > 0 else { return }
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//        withAnimation(.easeInOut(duration: 0.18)) {
//            currentIndex -= 1
//        }
//    }
//
//    // MARK: - Actions (operate on a specific crumb)
//
//    private func exportBreadcrumb(_ breadcrumb: Breadcrumb) {
//        ExportManager.exportSingleCrumb(breadcrumb) { url in
//            if let url = url {
//                exportURL = url
//                showingShareSheet = true
//            } else {
//                print("Export failed.")
//            }
//        }
//    }
//
//    private func toggleFavoriteStatus(_ breadcrumb: Breadcrumb) {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//}
//
//// MARK: - Content View (same UI, no environment-object juggling needed)
//
//private struct BreadcrumbDetailContentView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//
//    @Binding var exportURL: URL?
//    @Binding var showingShareSheet: Bool
//    @Binding var showFullScreenImage: Bool
//    @Binding var selectedTab: Tab
//
//    let onHome: () -> Void
//    let onDropCrumb: () -> Void
//    let onMap: () -> Void
//    let onGroups: () -> Void
//    let onProfile: () -> Void
//    let onNavigate: () -> Void
//    let onEdit: () -> Void
//    let onExport: () -> Void
//    let onToggleFavorite: () -> Void
//    let onBack: () -> Void
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea()
//
//            VStack(spacing: 0) {
//                ScrollView {
//                    VStack(spacing: 10) {
//                        BreadcrumbHeaderView(breadcrumb: breadcrumb)
//                        BreadcrumbImageView(breadcrumb: breadcrumb, showFullScreenImage: $showFullScreenImage)
//                        LocationDateView(breadcrumb: breadcrumb)
//                        NotesView(breadcrumb: breadcrumb)
//
//                        if #available(iOS 18, *) {
//                            CrumbMapView(nonIdCrumb: NonIdentifiableBreadcrumb(breadcrumb: breadcrumb))
//                        }
//
//                        Spacer().frame(height: 80)
//                    }
//                    .padding(.horizontal)
//                }
//
//                BottomNavigationBar(
//                    selectedTab: $selectedTab,
//                    onHome: onHome,
//                    onDropCrumb: onDropCrumb,
//                    onMap: onMap,
//                    onGroups: onGroups,
//                    onProfile: onProfile,
//                    onNavigate: onNavigate,
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false,
//                    showNavigate: true
//                )
//                .frame(height: 60)
//            }
//        }
//        .navigationTitle("Pin Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: onEdit) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: onToggleFavorite) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: onBack) {
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
//                Button(action: onExport) {
//                    Image(systemName: "square.and.arrow.up")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color(.white))
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//        .sheet(isPresented: $showingShareSheet) {
//            if let url = exportURL {
//                ShareSheet(activityItems: [url])
//            }
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//private struct BreadcrumbHeaderView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack {
//            Text(breadcrumb.name ?? "Unnamed Pin")
//                .font(.largeTitle)
//                .bold()
//                .foregroundColor(Color("Dark Blue"))
//                .multilineTextAlignment(.center)
//                .padding(.top, 20)
//            HStack {
//                Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Blue"))
//            }
//        }
//    }
//}
//
//private struct BreadcrumbImageView: View {
//    let breadcrumb: Breadcrumb
//    @Binding var showFullScreenImage: Bool
//
//    var body: some View {
//        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//            Button(action: { showFullScreenImage.toggle() }) {
//                let imageAspectRatio = image.size.width / image.size.height
//                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                let buttonHeight = maxImageWidth / imageAspectRatio
//
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: maxImageWidth, height: buttonHeight)
//                    .background(Color.white)
//                    .cornerRadius(30)
//                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                    .padding(.horizontal, 20)
//            }
//            .padding(.bottom, 20)
//        } else {
//            Rectangle()
//                .fill(Color.gray.opacity(0.2))
//                .frame(height: 300)
//                .overlay(
//                    Text("No Image Available")
//                        .font(.headline)
//                        .foregroundColor(.gray)
//                )
//                .background(Color.white)
//                .cornerRadius(30)
//                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                .padding(.horizontal, 20)
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//private struct LocationDateView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        HStack(alignment: .top) {
//            VStack(alignment: .center, spacing: 10) {
//                Text("LOCATION")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formatAddress(from: breadcrumb))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//                HStack {
//                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                        .font(.system(size: 12))
//                        .foregroundColor(Color("Dark Blue"))
//                        .multilineTextAlignment(.center)
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//
//            Divider()
//                .frame(height: 100)
//                .bold()
//                .background(Color("Dark Blue"))
//
//            VStack(alignment: .center, spacing: 10) {
//                Text("DATE/TIME")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formattedDate(breadcrumb.dateDropped))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//        }
//        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//        .background(Color.white)
//        .cornerRadius(30)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
//        let streetAddress = breadcrumb.streetAddress ?? "No Address"
//        let city = breadcrumb.city ?? "No City"
//        let state = breadcrumb.state ?? "No State"
//        let zipCode = breadcrumb.zipCode ?? "No Zip"
//        return "\(streetAddress), \(city), \(state) \(zipCode)"
//    }
//}
//
//private struct NotesView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack(alignment: .center, spacing: 5) {
//            Text("Notes:")
//                .font(.headline)
//                .foregroundColor(Color("Light Orange"))
//            Text(breadcrumb.note ?? "No Notes")
//                .foregroundColor(Color("Dark Blue"))
//                .padding(.bottom)
//        }
//        .padding(.horizontal)
//    }
//}
//
//@available(iOS 18, *)
//private struct NonIdentifiableBreadcrumb {
//    let breadcrumb: Breadcrumb
//    var coordinate: CLLocationCoordinate2D {
//        CLLocationCoordinate2D(latitude: breadcrumb.latitude,
//                               longitude: breadcrumb.longitude)
//    }
//}
//
//@available(iOS 18, *)
//private struct DummyAnnotation: Identifiable {
//    let id = UUID()
//}
//
//@available(iOS 18, *)
//private struct CrumbMapView: View {
//    let nonIdCrumb: NonIdentifiableBreadcrumb
//
//    private var region: Binding<MKCoordinateRegion> {
//        .constant(
//            MKCoordinateRegion(
//                center: nonIdCrumb.coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//            )
//        )
//    }
//
//    var body: some View {
//        Map(
//            coordinateRegion: region,
//            interactionModes: .all,
//            showsUserLocation: false,
//            userTrackingMode: .constant(.none),
//            annotationItems: [DummyAnnotation()]
//        ) { _ in
//            MapMarker(coordinate: nonIdCrumb.coordinate, tint: .red)
//        }
//        .frame(height: 200)
//        .frame(maxWidth: .infinity)
//        .cornerRadius(15)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//        .padding(.horizontal, 20)
//    }
//}



// 01162026 - 1731
//import SwiftUI
//import MapKit
//import CoreData
//
//// BreadcrumbDetailView.swift
//
//struct BreadcrumbDetailView: View {
//    // Option A: pass the ordered crumbs and the starting index
//    let breadcrumbs: [Breadcrumb]
//
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    @State private var currentIndex: Int
//    @State private var exportURL: URL?
//    @State private var showingShareSheet = false
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home
//
//    // Swipe tuning
//    private let swipeThreshold: CGFloat = 70
//    private let swipeDominanceRatio: CGFloat = 1.2
//
//    init(breadcrumbs: [Breadcrumb], startIndex: Int) {
//        self.breadcrumbs = breadcrumbs
//        _currentIndex = State(initialValue: max(0, min(startIndex, breadcrumbs.count - 1)))
//    }
//
//    private var currentBreadcrumb: Breadcrumb {
//        // Safe fallback if list is empty (shouldn't happen, but humans gonna human)
//        if breadcrumbs.isEmpty {
//            // Create a dummy crash-free behavior
//            // NOTE: In practice you should never present this view with an empty array.
//            return Breadcrumb(context: viewContext)
//        }
//        return breadcrumbs[currentIndex]
//    }
//
//    var body: some View {
//        // Wrap the existing UI in a content view that observes the currently selected crumb
//        BreadcrumbDetailContentView(
//            breadcrumb: currentBreadcrumb,
//            viewContext: viewContext,
//            navigationModel: navigationModel,
//            exportURL: $exportURL,
//            showingShareSheet: $showingShareSheet,
//            showFullScreenImage: $showFullScreenImage,
//            selectedTab: $selectedTab,
//            onExport: exportBreadcrumb,
//            onToggleFavorite: toggleFavoriteStatus
//        )
//        // Force a refresh when the Core Data object changes so subviews rebind cleanly.
//        .id(currentBreadcrumb.objectID)
//        // High priority swipe so it wins over ScrollView when it's clearly horizontal.
//        .highPriorityGesture(
//            DragGesture(minimumDistance: 10, coordinateSpace: .local)
//                .onEnded { value in
//                    guard breadcrumbs.count > 1 else { return }
//
//                    let dx = value.translation.width
//                    let dy = value.translation.height
//
//                    // Only treat it as a page swipe if it is strongly horizontal.
//                    guard abs(dx) > abs(dy) * swipeDominanceRatio else { return }
//                    guard abs(dx) > swipeThreshold else { return }
//
//                    if dx < 0 {
//                        // swipe left -> next
//                        goNext()
//                    } else {
//                        // swipe right -> previous
//                        goPrevious()
//                    }
//                }
//        )
//    }
//
//    // MARK: - Paging
//
//    private func goNext() {
//        guard currentIndex < breadcrumbs.count - 1 else { return }
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//        withAnimation(.easeInOut(duration: 0.18)) {
//            currentIndex += 1
//        }
//    }
//
//    private func goPrevious() {
//        guard currentIndex > 0 else { return }
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//        withAnimation(.easeInOut(duration: 0.18)) {
//            currentIndex -= 1
//        }
//    }
//
//    // MARK: - Existing helper methods (unchanged behavior)
//
//    private func exportBreadcrumb() {
//        let crumb = currentBreadcrumb
//        ExportManager.exportSingleCrumb(crumb) { url in
//            if let url = url {
//                exportURL = url
//                showingShareSheet = true
//            } else {
//                print("Export failed.")
//            }
//        }
//    }
//
//    private func toggleFavoriteStatus() {
//        let crumb = currentBreadcrumb
//        crumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//}
//
//// MARK: - Content View (keeps your exact UI, just made it reusable)
//
//private struct BreadcrumbDetailContentView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    let viewContext: NSManagedObjectContext
//    let navigationModel: NavigationModel
//
//    @Binding var exportURL: URL?
//    @Binding var showingShareSheet: Bool
//    @Binding var showFullScreenImage: Bool
//    @Binding var selectedTab: Tab
//
//    let onExport: () -> Void
//    let onToggleFavorite: () -> Void
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea()
//
//            VStack(spacing: 0) {
//                ScrollView {
//                    VStack(spacing: 10) {
//                        BreadcrumbHeaderView(breadcrumb: breadcrumb)
//                        BreadcrumbImageView(breadcrumb: breadcrumb, showFullScreenImage: $showFullScreenImage)
//                        LocationDateView(breadcrumb: breadcrumb)
//                        NotesView(breadcrumb: breadcrumb)
//
//                        // iOS 18+ map, unchanged
//                        if #available(iOS 18, *) {
//                            CrumbMapView(nonIdCrumb: NonIdentifiableBreadcrumb(breadcrumb: breadcrumb))
//                        }
//
//                        Spacer().frame(height: 80)
//                    }
//                    .padding(.horizontal)
//                }
//
//                BottomNavigationBar(
//                    selectedTab: $selectedTab,
//                    onHome: { navigationModel.path = [.dashboard] },
//                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                    onMap: { navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb)) },
//                    onGroups: { navigationModel.path.append(.groupsList) },
//                    onProfile: { navigationModel.path.append(.editProfile) },
//                    onNavigate: { navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb)) },
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false,
//                    showNavigate: true
//                )
//                .frame(height: 60)
//            }
//        }
//        .navigationTitle("Pin Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb))
//                }) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: onToggleFavorite) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//
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
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: onExport) {
//                    Image(systemName: "square.and.arrow.up")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color(.white))
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//        .sheet(isPresented: $showingShareSheet) {
//            if let url = exportURL {
//                ShareSheet(activityItems: [url])
//            }
//        }
//    }
//
//    // Local helper functions for image loading (same behavior)
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//// MARK: - Subviews (unchanged)
//
//private struct BreadcrumbHeaderView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack {
//            Text(breadcrumb.name ?? "Unnamed Pin")
//                .font(.largeTitle)
//                .bold()
//                .foregroundColor(Color("Dark Blue"))
//                .multilineTextAlignment(.center)
//                .padding(.top, 20)
//            HStack {
//                Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Blue"))
//            }
//        }
//    }
//}
//
//private struct BreadcrumbImageView: View {
//    let breadcrumb: Breadcrumb
//    @Binding var showFullScreenImage: Bool
//
//    var body: some View {
//        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//            Button(action: { showFullScreenImage.toggle() }) {
//                let imageAspectRatio = image.size.width / image.size.height
//                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                let buttonHeight = maxImageWidth / imageAspectRatio
//
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: maxImageWidth, height: buttonHeight)
//                    .background(Color.white)
//                    .cornerRadius(30)
//                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                    .padding(.horizontal, 20)
//            }
//            .padding(.bottom, 20)
//        } else {
//            Rectangle()
//                .fill(Color.gray.opacity(0.2))
//                .frame(height: 300)
//                .overlay(
//                    Text("No Image Available")
//                        .font(.headline)
//                        .foregroundColor(.gray)
//                )
//                .background(Color.white)
//                .cornerRadius(30)
//                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                .padding(.horizontal, 20)
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//private struct LocationDateView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        HStack(alignment: .top) {
//            VStack(alignment: .center, spacing: 10) {
//                Text("LOCATION")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formatAddress(from: breadcrumb))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//                HStack {
//                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                        .font(.system(size: 12))
//                        .foregroundColor(Color("Dark Blue"))
//                        .multilineTextAlignment(.center)
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//
//            Divider()
//                .frame(height: 100)
//                .bold()
//                .background(Color("Dark Blue"))
//
//            VStack(alignment: .center, spacing: 10) {
//                Text("DATE/TIME")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formattedDate(breadcrumb.dateDropped))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//        }
//        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//        .background(Color.white)
//        .cornerRadius(30)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
//        let streetAddress = breadcrumb.streetAddress ?? "No Address"
//        let city = breadcrumb.city ?? "No City"
//        let state = breadcrumb.state ?? "No State"
//        let zipCode = breadcrumb.zipCode ?? "No Zip"
//        return "\(streetAddress), \(city), \(state) \(zipCode)"
//    }
//}
//
//private struct NotesView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack(alignment: .center, spacing: 5) {
//            Text("Notes:")
//                .font(.headline)
//                .foregroundColor(Color("Light Orange"))
//            Text(breadcrumb.note ?? "No Notes")
//                .foregroundColor(Color("Dark Blue"))
//                .padding(.bottom)
//        }
//        .padding(.horizontal)
//    }
//}
//
//@available(iOS 18, *)
//private struct NonIdentifiableBreadcrumb {
//    let breadcrumb: Breadcrumb
//    var coordinate: CLLocationCoordinate2D {
//        CLLocationCoordinate2D(latitude: breadcrumb.latitude,
//                               longitude: breadcrumb.longitude)
//    }
//}
//
//@available(iOS 18, *)
//private struct DummyAnnotation: Identifiable {
//    let id = UUID()
//}
//
//@available(iOS 18, *)
//private struct CrumbMapView: View {
//    let nonIdCrumb: NonIdentifiableBreadcrumb
//
//    private var region: Binding<MKCoordinateRegion> {
//        .constant(
//            MKCoordinateRegion(
//                center: nonIdCrumb.coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//            )
//        )
//    }
//
//    var body: some View {
//        Map(
//            coordinateRegion: region,
//            interactionModes: .all,
//            showsUserLocation: false,
//            userTrackingMode: .constant(.none),
//            annotationItems: [DummyAnnotation()]
//        ) { _ in
//            MapMarker(coordinate: nonIdCrumb.coordinate, tint: .red)
//        }
//        .frame(height: 200)
//        .frame(maxWidth: .infinity)
//        .cornerRadius(15)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//        .padding(.horizontal, 20)
//    }
//}



//import SwiftUI
//import MapKit
//
//// BreadcrumbDetailView.swift
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @State private var exportURL: URL?
//    @State private var showingShareSheet = false
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea()
//
//            VStack(spacing: 0) {
//                ScrollView {
//                    VStack(spacing: 10) {
//                        BreadcrumbHeaderView(breadcrumb: breadcrumb)
//                        BreadcrumbImageView(breadcrumb: breadcrumb, showFullScreenImage: $showFullScreenImage)
//                        LocationDateView(breadcrumb: breadcrumb)
//                        NotesView(breadcrumb: breadcrumb)
//                        // Use the iOS 18+ CrumbMapView by wrapping the breadcrumb in a non‑identifiable container.
//                        if #available(iOS 18, *) {
//                            CrumbMapView(nonIdCrumb: NonIdentifiableBreadcrumb(breadcrumb: breadcrumb))
//                        }
//                        Spacer().frame(height: 80)
//                    }
//                    .padding(.horizontal)
//                }
//
//                BottomNavigationBar(
//                    selectedTab: $selectedTab,
//                    onHome: { navigationModel.path = [.dashboard] },
//                    onDropCrumb: { navigationModel.path.append(.addBreadcrumb) },
//                    onMap: { navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb)) },
//                    onGroups: { navigationModel.path.append(.groupsList) },
//                    onProfile: { navigationModel.path.append(.editProfile) },
//                    onNavigate: { navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb)) },
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false,
//                    showNavigate: true
//                )
//                .frame(height: 60)
//            }
//        }
//        .navigationTitle("Pin Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb))
//                }) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//
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
//
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: exportBreadcrumb) {
//                    Image(systemName: "square.and.arrow.up")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color(.white))
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//        .sheet(isPresented: $showingShareSheet) {
//            if let url = exportURL {
//                ShareSheet(activityItems: [url])
//            }
//        }
//    }
//    
//    // MARK: - Helper Methods
//
//    private func exportBreadcrumb() {
//        ExportManager.exportSingleCrumb(breadcrumb) { url in
//            if let url = url {
//                exportURL = url
//                showingShareSheet = true
//            } else {
//                print("Export failed.")
//            }
//        }
//    }
//
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
//        let streetAddress = breadcrumb.streetAddress ?? "No Address"
//        let city = breadcrumb.city ?? "No City"
//        let state = breadcrumb.state ?? "No State"
//        let zipCode = breadcrumb.zipCode ?? "No Zip"
//        return "\(streetAddress), \(city), \(state) \(zipCode)"
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//// MARK: - Subviews
//
//private struct BreadcrumbHeaderView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack {
//            Text(breadcrumb.name ?? "Unnamed Pin")
//                .font(.largeTitle)
//                .bold()
//                .foregroundColor(Color("Dark Blue"))
//                .multilineTextAlignment(.center)
//                .padding(.top, 20)
//            HStack {
//                Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Blue"))
//            }
//        }
//    }
//}
//
//private struct BreadcrumbImageView: View {
//    let breadcrumb: Breadcrumb
//    @Binding var showFullScreenImage: Bool
//
//    var body: some View {
//        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//            Button(action: { showFullScreenImage.toggle() }) {
//                let imageAspectRatio = image.size.width / image.size.height
//                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                let buttonHeight = maxImageWidth / imageAspectRatio
//
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: maxImageWidth, height: buttonHeight)
//                    .background(Color.white)
//                    .cornerRadius(30)
//                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                    .padding(.horizontal, 20)
//            }
//            .padding(.bottom, 20)
//        } else {
//            Rectangle()
//                .fill(Color.gray.opacity(0.2))
//                .frame(height: 300)
//                .overlay(
//                    Text("No Image Available")
//                        .font(.headline)
//                        .foregroundColor(.gray)
//                )
//                .background(Color.white)
//                .cornerRadius(30)
//                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                .padding(.horizontal, 20)
//        }
//    }
//    
//    // Local helper functions for image loading.
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//    
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//private struct LocationDateView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        HStack(alignment: .top) {
//            VStack(alignment: .center, spacing: 10) {
//                Text("LOCATION")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formatAddress(from: breadcrumb))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//                HStack {
//                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                        .font(.system(size: 12))
//                        .foregroundColor(Color("Dark Blue"))
//                        .multilineTextAlignment(.center)
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//
//            Divider()
//                .frame(height: 100)
//                .bold()
//                .background(Color("Dark Blue"))
//
//            VStack(alignment: .center, spacing: 10) {
//                Text("DATE/TIME")
//                    .font(.title3)
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding(.top)
//                Text(formattedDate(breadcrumb.dateDropped))
//                    .font(.system(size: 12))
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center)
//            }
//            .frame(maxWidth: .infinity, alignment: .center)
//        }
//        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//        .background(Color.white)
//        .cornerRadius(30)
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//    }
//    
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//    
//    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
//        let streetAddress = breadcrumb.streetAddress ?? "No Address"
//        let city = breadcrumb.city ?? "No City"
//        let state = breadcrumb.state ?? "No State"
//        let zipCode = breadcrumb.zipCode ?? "No Zip"
//        return "\(streetAddress), \(city), \(state) \(zipCode)"
//    }
//}
//
//private struct NotesView: View {
//    let breadcrumb: Breadcrumb
//    var body: some View {
//        VStack(alignment: .center, spacing: 5) {
//            Text("Notes:")
//                .font(.headline)
//                .foregroundColor(Color("Light Orange"))
//            Text(breadcrumb.note ?? "No Notes")
//                .foregroundColor(Color("Dark Blue"))
//                .padding(.bottom)
//        }
//        .padding(.horizontal)
//    }
//}
//
//@available(iOS 18, *)
//private struct NonIdentifiableBreadcrumb {
//    let breadcrumb: Breadcrumb
//    var coordinate: CLLocationCoordinate2D {
//        CLLocationCoordinate2D(latitude: breadcrumb.latitude,
//                               longitude: breadcrumb.longitude)
//    }
//}
//
//@available(iOS 18, *)
//private struct DummyAnnotation: Identifiable {
//    let id = UUID()
//}
//
//@available(iOS 18, *)
//private struct CrumbMapView: View {
//    let nonIdCrumb: NonIdentifiableBreadcrumb
//    
//    private var region: Binding<MKCoordinateRegion> {
//        .constant(
//            MKCoordinateRegion(
//                center: nonIdCrumb.coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//            )
//        )
//    }
//    
//    var body: some View {
//        Map(
//            coordinateRegion: region,
//            interactionModes: .all,
//            showsUserLocation: false,
//            userTrackingMode: .constant(.none),
//            annotationItems: [DummyAnnotation()]
//        ) { _ in
//            MapMarker(coordinate: nonIdCrumb.coordinate, tint: .red)
//        }
//        .frame(height: 200)              // Fixed height
//        .frame(maxWidth: .infinity)       // Full width
//        .cornerRadius(15)                 // Rounded corners
//        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)  // Matching shadow
//        .padding(.horizontal, 20)
//    }
//}


//@available(iOS 18, *)
//private struct NonIdentifiableBreadcrumb {
//    let breadcrumb: Breadcrumb
//    var coordinate: CLLocationCoordinate2D {
//        CLLocationCoordinate2D(latitude: breadcrumb.latitude,
//                                  longitude: breadcrumb.longitude)
//    }
//}
//
//@available(iOS 18, *)
//private struct CrumbMapView: View {
//    let nonIdCrumb: NonIdentifiableBreadcrumb
//    private var region: Binding<MKCoordinateRegion> {
//        .constant(
//            MKCoordinateRegion(
//                center: nonIdCrumb.coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//            )
//        )
//    }
//    
//    var body: some View {
//        Map(
//            coordinateRegion: region,
//            interactionModes: .all,
//            showsUserLocation: false,
//            userTrackingMode: .constant(.none)
//        ) {
//            MapMarker(coordinate: nonIdCrumb.coordinate, tint: .red)
//        }
//        .frame(maxWidth: .infinity, maxHeight: 200)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//        .padding(.horizontal, 20)
//    }
//}







// 032625-1621
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//    @State private var exportURL: URL?
//    @State private var showingShareSheet = false
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home // Add selected tab state
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea() // Full-screen white background
//
//            VStack(spacing: 0) {
//                // Scrollable Content
//                ScrollView {
//                    VStack(spacing: 10) {
//                        // Breadcrumb Name
//                        Text(breadcrumb.name ?? "Unnamed Crumb")
//                            .font(.largeTitle)
//                            .bold()
//                            .foregroundColor(Color("Dark Blue"))
//                            .multilineTextAlignment(.center)
//                            .padding(.top, 20)
//
//                        // Group and Date
//                        HStack {
//                            Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                                .font(.headline)
//                                .foregroundColor(Color("Dark Blue"))
//                        }
//
//                        // Tap-to-Fullscreen Image
//                        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                            Button(action: {
//                                showFullScreenImage.toggle()
//                            }) {
//                                let imageAspectRatio = image.size.width / image.size.height
//                                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                                let buttonHeight = maxImageWidth / imageAspectRatio
//
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: maxImageWidth, height: buttonHeight)
//                                    .background(Color.white)
//                                    .cornerRadius(30)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20)
//                            }
//                            .padding(.bottom, 20)
//                        } else {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.2))
//                                .frame(height: 300)
//                                .overlay(
//                                    Text("No Image Available")
//                                        .font(.headline)
//                                        .foregroundColor(.gray)
//                                )
//                                .background(Color.white)
//                                .cornerRadius(30)
//                                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                .padding(.horizontal, 20)
//                        }
//
//                        // Location and Date/Time
//                        HStack(alignment: .top) {
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("LOCATION")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                // Display stored address information
//                                Text(formatAddress(from: breadcrumb))
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                                HStack {
//                                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//
//                            Divider()
//                                .frame(height: 100)
//                                .bold()
//                                .background(Color("Dark Blue"))
//
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("DATE/TIME")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                Text("\(formattedDate(breadcrumb.dateDropped))")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//                        .background(Color.white)
//                        .cornerRadius(30)
//                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//
//                        // Notes Section
//                        VStack(alignment: .center, spacing: 5) {
//                            Text("Notes:")
//                                .font(.headline)
//                                .foregroundColor(Color("Light Orange"))
//                            Text(breadcrumb.note ?? "No Notes")
//                                .foregroundColor(Color("Dark Blue"))
//                                .padding(.bottom)
//                        }
//                        .padding(.horizontal)
//                        
//                        CrumbMapView(breadcrumb: breadcrumb)
//                    }
//                    .padding(.horizontal)
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
//                        navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb))
//                    },
//                    onGroups: {
//                        navigationModel.path.append(.groupsList)
//                    },
//                    onProfile: {
//                        navigationModel.path.append(.editProfile)
//                    },
//                    onNavigate: { navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb))
//                    },
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false,
//                    showNavigate: true
//                )
//                .frame(height: 60)
//            }
//        }
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            // Edit Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb)) // Append the navigation destination
//                }) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            // Favorite Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: {
//                    // Navigate back dynamically
//                    navigationModel.path.removeLast()
//                }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: exportBreadcrumb) {
//                    Image(systemName: "square.and.arrow.up")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color(.white))
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//        .sheet(isPresented: $showingShareSheet, content: {
//            if let url = exportURL {
//                ShareSheet(activityItems: [url])
//            }
//        })
//    }
//    
//    @available(iOS 18, *)
//    struct NonIdentifiableBreadcrumb {
//        let breadcrumb: Breadcrumb
//        var coordinate: CLLocationCoordinate2D {
//            CLLocationCoordinate2D(latitude: breadcrumb.latitude,
//                                   longitude: breadcrumb.longitude)
//        }
//    }
//
//    @available(iOS 18, *)
//    struct CrumbMapView: View {
//        let nonIdCrumb: NonIdentifiableBreadcrumb
//
//        private var region: Binding<MKCoordinateRegion> {
//            .constant(
//                MKCoordinateRegion(
//                    center: nonIdCrumb.coordinate,
//                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                )
//            )
//        }
//        
//        var body: some View {
//            Map(
//                coordinateRegion: region,
//                interactionModes: .all,
//                showsUserLocation: false,
//                userTrackingMode: .constant(.none)
//            ) {
//                MapMarker(coordinate: nonIdCrumb.coordinate, tint: .red)
//            }
//            .frame(maxWidth: .infinity, maxHeight: 200)
//            .cornerRadius(15)
//            .shadow(radius: 5)
//            .padding(.horizontal, 20)
//        }
//    }
//
//     private func exportBreadcrumb() {
//        ExportManager.exportSingleCrumb(breadcrumb) { url in
//            if let url = url {
//                exportURL = url
//                showingShareSheet = true
//            } else {
//                print("Export failed.")
//            }
//        }
//    }
//
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
//        let streetAddress = breadcrumb.streetAddress ?? "No Address"
//        let city = breadcrumb.city ?? "No City"
//        let state = breadcrumb.state ?? "No State"
//        let zipCode = breadcrumb.zipCode ?? "No Zip"
//
//        return "\(streetAddress), \(city), \(state) \(zipCode)"
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}


//import SwiftUI
//import CoreLocation
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home
//
//    // Geocoded location properties
//    @State private var city: String = "Fetching..."
//    @State private var state: String = "Fetching..."
//    @State private var zipCode: String = "Fetching..."
//    @State private var geocoder = CLGeocoder()
//
//    var body: some View {
//        NavigationStack(path: $navigationModel.path) {
//            ZStack {
//                Color.white.ignoresSafeArea()
//
//                VStack(spacing: 0) {
//                    // Scrollable Content
//                    ScrollView {
//                        VStack(spacing: 10) {
//                            // Breadcrumb Name
//                            Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                                .font(.largeTitle)
//                                .bold()
//                                .foregroundColor(Color("Dark Blue"))
//                                .multilineTextAlignment(.center)
//                                .padding(.top, 20)
//
//                            // Group and Date
//                            HStack {
//                                Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                                    .font(.headline)
//                                    .foregroundColor(Color("Dark Blue"))
//                            }
//
//                            // Tap-to-Fullscreen Image
//                            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                                Button(action: {
//                                    showFullScreenImage.toggle()
//                                }) {
//                                    let imageAspectRatio = image.size.width / image.size.height
//                                    let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                                    let buttonHeight = maxImageWidth / imageAspectRatio
//
//                                    Image(uiImage: image)
//                                        .resizable()
//                                        .scaledToFit()
//                                        .frame(width: maxImageWidth, height: buttonHeight)
//                                        .background(Color.white)
//                                        .cornerRadius(30)
//                                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                        .padding(.horizontal, 20)
//                                }
//                                .padding(.bottom, 20)
//                            } else {
//                                Rectangle()
//                                    .fill(Color.gray.opacity(0.2))
//                                    .frame(height: 300)
//                                    .overlay(
//                                        Text("No Image Available")
//                                            .font(.headline)
//                                            .foregroundColor(.gray)
//                                    )
//                                    .background(Color.white)
//                                    .cornerRadius(30)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20)
//                            }
//
//                            // Location and Date/Time
//                            HStack(alignment: .top) {
//                                VStack(alignment: .center, spacing: 10) {
//                                    Text("LOCATION")
//                                        .font(.title3)
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .padding(.top)
//                                    Text("\(city), \(state) \(zipCode)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                    HStack {
//                                        Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                                            .font(.system(size: 12))
//                                            .foregroundColor(Color("Dark Blue"))
//                                            .multilineTextAlignment(.center)
//                                    }
//                                }
//                                .frame(maxWidth: .infinity, alignment: .center)
//
//                                Divider()
//                                    .frame(height: 100)
//                                    .bold()
//                                    .background(Color("Dark Blue"))
//
//                                VStack(alignment: .center, spacing: 10) {
//                                    Text("DATE/TIME")
//                                        .font(.title3)
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .padding(.top)
//                                    Text("\(formattedDate(breadcrumb.dateDropped))")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                                .frame(maxWidth: .infinity, alignment: .center)
//                            }
//                            .frame(maxWidth: UIScreen.main.bounds.width - 40)
//                            .background(Color.white)
//                            .cornerRadius(30)
//                            .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//
//                            // Notes Section
//                            VStack(alignment: .center, spacing: 5) {
//                                Text("Notes:")
//                                    .font(.headline)
//                                    .foregroundColor(Color("Light Orange"))
//                                Text(breadcrumb.note ?? "No Notes")
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.bottom)
//                            }
//                            .padding(.horizontal)
//                        }
//                        .padding(.horizontal)
//                    }
//
//                    // Bottom Navigation Bar
//                    BottomNavigationBar(
//                        selectedTab: $selectedTab,
//                        onHome: {
//                            navigationModel.path = [.dashboard]
//                        },
//                        onDropCrumb: {
//                            navigationModel.path.append(.addBreadcrumb)
//                        },
//                        onMap: {
//                            navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb))
//                        },
//                        onGroups: {
//                            navigationModel.path.append(.groupsList)
//                        },
//                        onProfile: {
//                            navigationModel.path.append(.editProfile)
//                        },
//                        onNavigate: {
//                            navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb))
//                        },
//                        showHome: true,
//                        showDropCrumb: true,
//                        showMap: true,
//                        showGroups: true,
//                        showProfile: false,
//                        showNavigate: true
//                    )
//                    .frame(height: 60)
//                }
//            }
//        }
//        .onAppear {
//            fetchGeocodedLocation()
//        }
//        .navigationTitle("Breadcrumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//    }
//
//    // MARK: - Helper Methods
//    private func fetchGeocodedLocation() {
//        let location = CLLocation(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude)
//
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//                return
//            }
//
//            if let placemark = placemarks?.first {
//                DispatchQueue.main.async {
//                    self.city = placemark.locality ?? "Unknown"
//                    self.state = placemark.administrativeArea ?? "Unknown"
//                    self.zipCode = placemark.postalCode ?? "Unknown"
//                }
//            } else {
//                print("No placemarks found.")
//                DispatchQueue.main.async {
//                    self.city = "Unknown"
//                    self.state = "Unknown"
//                    self.zipCode = "Unknown"
//                }
//            }
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}


//import SwiftUI
//import CoreLocation
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Shared LocationManager instance
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home // Add selected tab state
//
//    // Geocoded location properties
//    @State private var city: String = "Fetching..."
//    @State private var state: String = "Fetching..."
//    @State private var zipCode: String = "Fetching..."
//    @State private var geocoder = CLGeocoder()
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea() // Full-screen white background
//
//            VStack(spacing: 0) {
//                // Scrollable Content
//                ScrollView {
//                    VStack(spacing: 10) {
//                        // Breadcrumb Name
//                        Text(breadcrumb.name ?? "Unnamed Crumb")
//                            .font(.largeTitle)
//                            .bold()
//                            .foregroundColor(Color("Dark Blue"))
//                            .multilineTextAlignment(.center)
//                            .padding(.top, 20)
//
//                        // Group and Date
//                        HStack {
//                            Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                                .font(.headline)
//                                .foregroundColor(Color("Dark Blue"))
//                        }
//
//                        // Tap-to-Fullscreen Image
//                        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                            Button(action: {
//                                showFullScreenImage.toggle()
//                            }) {
//                                let imageAspectRatio = image.size.width / image.size.height
//                                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                                let buttonHeight = maxImageWidth / imageAspectRatio
//
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: maxImageWidth, height: buttonHeight)
//                                    .background(Color.white)
//                                    .cornerRadius(30)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20)
//                            }
//                            .padding(.bottom, 20)
//                        } else {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.2))
//                                .frame(height: 300)
//                                .overlay(
//                                    Text("No Image Available")
//                                        .font(.headline)
//                                        .foregroundColor(.gray)
//                                )
//                                .background(Color.white)
//                                .cornerRadius(30)
//                                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                .padding(.horizontal, 20)
//                        }
//
//                        // Location and Date/Time
//                        HStack(alignment: .top) {
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("LOCATION")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                Text("\(city), \(state) \(zipCode)")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                                HStack {
//                                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//
//                            Divider()
//                                .frame(height: 100)
//                                .bold()
//                                .background(Color("Dark Blue"))
//
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("DATE/TIME")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                Text("\(formattedDate(breadcrumb.dateDropped))")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//                        .background(Color.white)
//                        .cornerRadius(30)
//                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//
//                        // Notes Section
//                        VStack(alignment: .center, spacing: 5) {
//                            Text("Notes:")
//                                .font(.headline)
//                                .foregroundColor(Color("Light Orange"))
//                            Text(breadcrumb.note ?? "No Notes")
//                                .foregroundColor(Color("Dark Blue"))
//                                .padding(.bottom)
//                        }
//                        .padding(.horizontal)
//                    }
//                    .padding(.horizontal)
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
//                        navigationModel.path.append(.breadcrumbMap(breadcrumb: breadcrumb))
//                    },
//                    onGroups: {
//                        navigationModel.path.append(.groupsList)
//                    },
//                    onProfile: {
//                        navigationModel.path.append(.editProfile)
//                    },
//                    onNavigate: { navigationModel.path.append(.navigateToLocation(breadcrumb: breadcrumb))
//                    },
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false,
//                    showNavigate: true
//                )
//                .frame(height: 60)
//            }
//        }
//        .onAppear {
//            fetchGeocodedLocation()
//        }
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            // Edit Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb)) // Append the navigation destination
//                }) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            // Favorite Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: {
//                    // Navigate back dynamically
//                    navigationModel.path.removeLast()
//                }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//
//    }
//    
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    private func fetchGeocodedLocation() {
//        let location = CLLocation(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude)
//
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//                return
//            }
//
//            if let placemark = placemarks?.first {
//                DispatchQueue.main.async {
//                    self.city = placemark.locality ?? "Unknown"
//                    self.state = placemark.administrativeArea ?? "Unknown"
//                    self.zipCode = placemark.postalCode ?? "Unknown"
//                }
//            } else {
//                print("No placemarks found.")
//                DispatchQueue.main.async {
//                    self.city = "Unknown"
//                    self.state = "Unknown"
//                    self.zipCode = "Unknown"
//                }
//            }
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}

//import SwiftUI
//import CoreLocation
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Shared LocationManager instance
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home // Add selected tab state
//
//    // Geocoded location properties
//    @State private var city: String = "Fetching..."
//    @State private var state: String = "Fetching..."
//    @State private var zipCode: String = "Fetching..."
//    @State private var geocoder = CLGeocoder()
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea() // Full-screen white background
//
//            VStack(spacing: 0) {
//                // Scrollable Content
//                ScrollView {
//                    VStack(spacing: 10) {
//                        // Breadcrumb Name
//                        Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                            .font(.largeTitle)
//                            .bold()
//                            .foregroundColor(Color("Dark Blue"))
//                            .multilineTextAlignment(.center)
//                            .padding(.top, 20)
//
//                        // Group and Date
//                        HStack {
//                            Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                                .font(.headline)
//                                .foregroundColor(Color("Dark Blue"))
//                        }
//
//                        // Tap-to-Fullscreen Image
//                        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                            Button(action: {
//                                showFullScreenImage.toggle()
//                            }) {
//                                let imageAspectRatio = image.size.width / image.size.height
//                                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40
//                                let buttonHeight = maxImageWidth / imageAspectRatio
//
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: maxImageWidth, height: buttonHeight)
//                                    .background(Color.white)
//                                    .cornerRadius(30)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20)
//                            }
//                            .padding(.bottom, 20)
//                        } else {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.2))
//                                .frame(height: 300)
//                                .overlay(
//                                    Text("No Image Available")
//                                        .font(.headline)
//                                        .foregroundColor(.gray)
//                                )
//                                .background(Color.white)
//                                .cornerRadius(30)
//                                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                .padding(.horizontal, 20)
//                        }
//
//                        // Location and Date/Time
//                        HStack(alignment: .top) {
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("LOCATION")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                Text("\(city), \(state) \(zipCode)")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                                HStack {
//                                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//
//                            Divider()
//                                .frame(height: 100)
//                                .bold()
//                                .background(Color("Dark Blue"))
//
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("DATE/TIME")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                Text("\(formattedDate(breadcrumb.dateDropped))")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//                        .background(Color.white)
//                        .cornerRadius(30)
//                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//
//                        // Notes Section
//                        VStack(alignment: .center, spacing: 5) {
//                            Text("Notes:")
//                                .font(.headline)
//                                .foregroundColor(Color("Light Orange"))
//                            Text(breadcrumb.note ?? "No Notes")
//                                .foregroundColor(Color("Dark Blue"))
//                                .padding(.bottom)
//                        }
//                        .padding(.horizontal)
//                    }
//                    .padding(.horizontal)
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
//                        navigationModel.path.append(.breadcrumbMap(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude, name: breadcrumb.name ?? "Location"))
//                    },
//                    onGroups: {
//                        navigationModel.path.append(.groupsList)
//                    },
//                    onProfile: {
//                        navigationModel.path.append(.editProfile)
//                    },
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false
//                )
//                .frame(height: 60)
//            }
//        }
//        .onAppear {
//            fetchGeocodedLocation()
//        }
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func fetchGeocodedLocation() {
//        // Use latitude and longitude directly since they are non-optional
//        let latitude = breadcrumb.latitude
//        let longitude = breadcrumb.longitude
//
//        let location = CLLocation(latitude: latitude, longitude: longitude)
//
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//                return
//            }
//
//            if let placemark = placemarks?.first {
//                DispatchQueue.main.async {
//                    self.city = placemark.locality ?? "Unknown"
//                    self.state = placemark.administrativeArea ?? "Unknown"
//                    self.zipCode = placemark.postalCode ?? "Unknown"
//                }
//            } else {
//                print("No placemarks found.")
//                DispatchQueue.main.async {
//                    self.city = "Unknown"
//                    self.state = "Unknown"
//                    self.zipCode = "Unknown"
//                }
//            }
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}


//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Use shared LocationManager instance
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home // Add selected tab state
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea() // Full-screen white background
//
//            VStack(spacing: 0) {
//                // Scrollable Content
//                ScrollView {
//                    VStack(spacing: 10) {
//                        // Breadcrumb Name
//                        Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                            .font(.largeTitle)
//                            .bold()
//                            .foregroundColor(Color("Dark Blue"))
//                            .multilineTextAlignment(.center)
//                            .padding(.top, 20)
//
//                        // Group and Date
//                        HStack {
//                            Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                                .font(.headline)
//                                .foregroundColor(Color("Dark Blue"))
//                        }
//
//                        // Tap-to-Fullscreen Image
//                        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                            Button(action: {
//                                showFullScreenImage.toggle()
//                            }) {
//                                let imageAspectRatio = image.size.width / image.size.height
//                                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40 // Adjust based on screen width and padding
//                                let buttonHeight = maxImageWidth / imageAspectRatio // Calculate height dynamically
//
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: maxImageWidth, height: buttonHeight) // Set explicit width and height
//                                    .background(Color.white)
//                                    .cornerRadius(30)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20) // Add horizontal padding
//                            }
//                            .padding(.bottom, 20) // Add spacing to avoid overlap with subsequent content
//                        } else {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.2))
//                                .frame(height: 300)
//                                .overlay(
//                                    Text("No Image Available")
//                                        .font(.headline)
//                                        .foregroundColor(.gray)
//                                )
//                                .background(Color.white)
//                                .cornerRadius(30)
//                                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                .padding(.horizontal, 20) // Add consistent horizontal padding
//                        }
//
//                        // Location and Date/Time
//                        HStack(alignment: .top) {
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("LOCATION")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                HStack {
//                                    Text("\(locationManager.city), \(locationManager.state) \(locationManager.zipCode)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                                HStack {
//                                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//
//                            Divider()
//                                .frame(height: 100)
//                                .bold()
//                                .background(Color("Dark Blue"))
//
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("DATE/TIME")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                Text("\(formattedDate(breadcrumb.dateDropped))")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//                        .background(Color.white)
//                        .cornerRadius(30)
//                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//
//                        // Notes Section
//                        VStack(alignment: .center, spacing: 5) {
//                            Text("Notes:")
//                                .font(.headline)
//                                .foregroundColor(Color("Light Orange"))
//                            Text(breadcrumb.note ?? "No Notes")
//                                .foregroundColor(Color("Dark Blue"))
//                                .padding(.bottom)
//                        }
//                        .padding(.horizontal)
//                    }
//                    .padding(.horizontal)
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
//                        navigationModel.path.append(.breadcrumbMap(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude, name: breadcrumb.name ?? "Location"))
//                    },
//                    onGroups: {
//                        navigationModel.path.append(.groupsList)
//                    },
//                    onProfile: {
//                        navigationModel.path.append(.editProfile)
//                    },
//                    showHome: true,
//                    showDropCrumb: true,
//                    showMap: true,
//                    showGroups: true,
//                    showProfile: false
//                )
//                .frame(height: 60)
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation() // Ensure location updates are requested
//        }
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}


//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @StateObject private var locationManager = LocationManager()
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home // Add selected tab state
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea() // Full-screen white background
//
//            VStack(spacing: 0) {
//                // Scrollable Content
//                ScrollView {
//                    VStack(spacing: 10) {
//                        // Breadcrumb Name
//                        Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                            .font(.largeTitle)
//                            .bold()
//                            .foregroundColor(Color("Dark Blue"))
//                            .multilineTextAlignment(.center)
//                            .padding(.top, 20)
//
//                        // Group and Date
//                        HStack {
//                            Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                                .font(.headline)
//                                .foregroundColor(Color("Dark Blue"))
//                        }
//
//                        // Tap-to-Fullscreen Image
//                        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                            Button(action: {
//                                showFullScreenImage.toggle()
//                            }) {
//                                let imageAspectRatio = image.size.width / image.size.height
//                                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40 // Adjust based on screen width and padding
//                                let buttonHeight = maxImageWidth / imageAspectRatio // Calculate height dynamically
//
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: maxImageWidth, height: buttonHeight) // Set explicit width and height
//                                    .background(Color.white)
//                                    .cornerRadius(30)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20) // Add horizontal padding
//                            }
//                            .padding(.bottom, 20) // Add spacing to avoid overlap with subsequent content
//                        } else {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.2))
//                                .frame(height: 300)
//                                .overlay(
//                                    Text("No Image Available")
//                                        .font(.headline)
//                                        .foregroundColor(.gray)
//                                )
//                                .background(Color.white)
//                                .cornerRadius(30)
//                                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                .padding(.horizontal, 20) // Add consistent horizontal padding
//                        }
//
//                        // Location and Date/Time
//                        HStack(alignment: .top) {
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("LOCATION")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                HStack {
//                                    Text("\(locationManager.city), \(locationManager.state) \(locationManager.zipCode)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                                HStack {
//                                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//
//                            Divider()
//                                .frame(height: 100)
//                                .bold()
//                                .background(Color("Dark Blue"))
//
//                            VStack(alignment: .center, spacing: 10) {
//                                Text("DATE/TIME")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.top)
//                                Text("\(formattedDate(breadcrumb.dateDropped))")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
//                        .background(Color.white)
//                        .cornerRadius(30)
//                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//
//                        // Notes Section
//                        VStack(alignment: .center, spacing: 5) {
//                            Text("Notes:")
//                                .font(.headline)
//                                .foregroundColor(Color("Light Orange"))
//                            Text(breadcrumb.note ?? "No Notes")
//                                .foregroundColor(Color("Dark Blue"))
//                                .padding(.bottom)
//                        }
//                        .padding(.horizontal)
//
////                        // Navigate to MapView
////                        Button(action: {
////                            navigationModel.path.append(.breadcrumbMap(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude, name: breadcrumb.name ?? "Location"))
////                        }) {
////                            Text("View on Map")
////                                .frame(maxWidth: .infinity)
////                                .padding()
////                                .background(Color("Light Orange"))
////                                .foregroundColor(Color("Dark Blue"))
////                                .cornerRadius(10)
////                        }
////                        .padding(.horizontal)
//                    }
//                    .padding(.horizontal)
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
//                        navigationModel.path.append(.breadcrumbMap(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude, name: breadcrumb.name ?? "Location"))
//                    },
//                    onGroups: {
//                        navigationModel.path.append(.groupsList)
//                    },
//                    onProfile: {
//                        navigationModel.path.append(.editProfile)
//                    },
//                    showHome: true,        // Show Home button
//                    showDropCrumb: true,  // Hide Drop Crumb button
//                    showMap: true,         // Show Map button
//                    showGroups: true,      // Show Groups button
//                    showProfile: false     // Hide Profile button
//                )
//                .frame(height: 60)            }
//        }
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            // Edit Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    navigationModel.path.append(.editBreadcrumb(breadcrumb: breadcrumb))
//                }) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            // Favorite Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//    }
//
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}




//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @StateObject private var locationManager = LocationManager()
//    @State private var showFullScreenImage = false
//    @State private var selectedTab: Tab = .home // Add selected tab state
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea() // Full-screen white background
//
//            VStack(spacing: 0) {
//                // Scrollable Content
//                ScrollView {
//                    VStack(spacing: 10) {
//                        // Breadcrumb Name
//                        Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                            .font(.largeTitle)
//                            .bold()
//                            .foregroundColor(Color("Dark Blue"))
//                            .multilineTextAlignment(.center)
//                            .padding(.top, 20)
//
//                        // Group and Date
//                        HStack {
//                            Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                                .font(.headline)
//                                .foregroundColor(Color("Dark Blue"))
//                        }
//
//                        // Tap-to-Fullscreen Image
//                        if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                            Button(action: {
//                                showFullScreenImage.toggle()
//                            }) {
//                                let imageAspectRatio = image.size.width / image.size.height
//                                let maxImageWidth: CGFloat = UIScreen.main.bounds.width - 40 // Adjust based on screen width and padding
//                                let buttonHeight = maxImageWidth / imageAspectRatio // Calculate height dynamically
//
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: maxImageWidth, height: buttonHeight) // Set explicit width and height
//                                    .background(Color.white)
//                                    .cornerRadius(30)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20) // Add horizontal padding
//                            }
//                            .padding(.bottom, 20) // Add spacing to avoid overlap with subsequent content
//                        } else {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.2))
//                                .frame(height: 300)
//                                .overlay(
//                                    Text("No Image Available")
//                                        .font(.headline)
//                                        .foregroundColor(.gray)
//                                )
//                                .background(Color.white)
//                                .cornerRadius(30)
//                                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                .padding(.horizontal, 20) // Add consistent horizontal padding
//                        }
//
//
//                        // Location and Date/Time
//                        HStack {
//                            VStack {
//                                Text("LOCATION")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.bottom)
//                                HStack {
//                                    Text("\(locationManager.city), \(locationManager.state) \(locationManager.zipCode)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                                HStack {
//                                    Text("\(breadcrumb.latitude), \(breadcrumb.longitude)")
//                                        .font(.system(size: 12))
//                                        .foregroundColor(Color("Dark Blue"))
//                                        .multilineTextAlignment(.center)
//                                }
//                            }
//                            .frame(maxWidth: .infinity)
//
//                            Divider()
//                                .frame(height: 100)
//                                .bold()
//                                .background(Color("Dark Blue"))
//
//                            VStack {
//                                Text("DATE/TIME")
//                                    .font(.title3)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding(.bottom)
//                                Text("\(formattedDate(breadcrumb.dateDropped))")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .multilineTextAlignment(.center)
//                            }
//                            .frame(maxWidth: .infinity)
//                        }
//                        .background(Color.white)
//                        .cornerRadius(30)
//                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//
//                        // Notes Section
//                        VStack(alignment: .center, spacing: 5) {
//                            Text("Notes:")
//                                .font(.headline)
//                                .foregroundColor(Color("Light Orange"))
//                            Text(breadcrumb.note ?? "No Notes")
//                                .foregroundColor(Color("Dark Blue"))
//                                .padding(.bottom)
//                        }
//                        .padding(.horizontal)
//
//                        // Navigate to MapView
//                        NavigationLink(
//                            destination: BreadcrumbMapView(
//                                latitude: breadcrumb.latitude,
//                                longitude: breadcrumb.longitude,
//                                name: breadcrumb.name ?? "Location"
//                            )
//                        ) {
//                            Text("View on Map")
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color("Light Orange"))
//                                .foregroundColor(Color("Dark Blue"))
//                                .cornerRadius(10)
//                        }
//                        .padding(.horizontal)
//                    }
//                    .padding(.horizontal)
//                }
//
//                // Bottom Navigation Bar
//                BottomNavigationBar(selectedTab: $selectedTab)
//                    .frame(height: 60)
//            }
//        }
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            // Edit Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: EditBreadcrumbView(breadcrumb: breadcrumb)) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange"))
//                }
//            }
//
//            // Favorite Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//    }
//
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}



//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @StateObject private var locationManager = LocationManager()
//    @State private var showFullScreenImage = false // Track full-screen image view
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 10) {
//                // Breadcrumb Name
//                Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                    .font(.largeTitle)
//                    .bold()
//                    .foregroundColor(Color("Dark Blue"))
//                    .multilineTextAlignment(.center) // Center-align the text
//                    .padding(.top, 20) // Add padding to ensure it's not clipped at the top
//
//                // Group and Date
//                HStack {
//                    Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                        .font(.headline)
//                        .foregroundColor(Color("Dark Blue"))
//                }
//                
//                // Tap-to-Fullscreen Image
//                if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                    Button(action: {
//                        showFullScreenImage.toggle()
//                    }) {
//                        Image(uiImage: image)
//                            .resizable()
//                            .scaledToFit()
//                            .frame(maxWidth: .infinity, maxHeight: 350)
//                            //.padding()
//                            .background(Color.white)
//                            .cornerRadius(30)
//                            .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)                    }
//                } else {
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(height: 300)
//                        .overlay(
//                            Text("No Image Available")
//                                .font(.headline)
//                                .foregroundColor(.gray)
//                        )
//                        .padding()
//                        .background(Color.white)
//                        .cornerRadius(30)
//                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)                }
//                
//                HStack {
//                    VStack(alignment: .center) {
//                        Text("LOCATION")
//                            .font(.title3)
//                            .foregroundColor(Color("Dark Blue"))
//                            .padding(.bottom)
//                        HStack {
//                            Text("\(locationManager.city), ")
//                                .font(.system(size: 12))
//                            Text("\(locationManager.state)")
//                                .font(.system(size: 12))
//                            Text(" \(locationManager.zipCode)")
//                                .font(.system(size: 12))
//
//                        }
//
//                        HStack {
//                            Text("\(breadcrumb.latitude)")
//                                .font(.system(size: 12))
//                                .foregroundColor(Color("Dark Blue"))
//                                .multilineTextAlignment(.center)
//                            
//                            Text(", ")
//                                .font(.system(size: 12))
//                                .foregroundColor(Color("Dark Blue"))
//                                .multilineTextAlignment(.center)
//                            
//                            Text("\(breadcrumb.longitude)")
//                                .font(.system(size: 12))
//                                .foregroundColor(Color("Dark Blue"))
//                                .multilineTextAlignment(.center)
//                        }
//                    }
//                    .frame(maxWidth: .infinity) // Make VStack occupy equal width
//                    //.padding()
//
//                    Divider()
//                        .frame(height: 100) // Adjust height as needed
//                        .bold()
//                        .background(Color("Dark Blue")) // Correct color application
//
//                    VStack {
//                        Text("DATE/TIME")
//                            .font(.title3)
//                            .foregroundColor(Color("Dark Blue"))
//                            .padding(.bottom)
//                        Text("\(formattedDate(breadcrumb.dateDropped))")
//                            .font(.system(size: 12))
//                            .foregroundColor(Color("Dark Blue"))
//                            .multilineTextAlignment(.center)
//                    }
//                    .frame(maxWidth: .infinity) // Make VStack occupy equal width
//                    .padding()
//                }
//                .background(Color.white)
//                .cornerRadius(30)
//                .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                
//
//                // Notes Section
//                VStack(alignment: .center, spacing: 5) {
//                    Text("Notes:")
//                        .font(.headline)
//                        .foregroundColor(Color("Light Orange"))
//                    Text(breadcrumb.note ?? "No Notes")
//                        .foregroundColor(Color("Dark Blue"))
//                        .padding(.bottom)
//                }
//                .padding(.horizontal)
//
//                // Navigate to MapView
//                NavigationLink(
//                    destination: BreadcrumbMapView(
//                        latitude: breadcrumb.latitude,
//                        longitude: breadcrumb.longitude,
//                        name: breadcrumb.name ?? "Location"
//                    )
//                ) {
//                    Text("View on Map")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Light Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .cornerRadius(10)
//                }
//                .padding(.horizontal)
//            }
//            .padding(.horizontal)
//        }
//        .background(Color.white.ignoresSafeArea()) // Dynamic background color
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            // Edit Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: EditBreadcrumbView(breadcrumb: breadcrumb)) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange")) // Dynamic toolbar icon color
//                }
//            }
//
//            // Favorite Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//    }
//
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save() // Save changes to Core Data
//            print("Favorite status updated to: \(breadcrumb.isFavorite)")
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    // MARK: - Helper Functions
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}



//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//
//    @State private var showFullScreenImage = false // Track full-screen image view
//
//    var body: some View {
//        ScrollView {
//            Spacer()
//            VStack(spacing: 10) {
//                // Breadcrumb Name
//                Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                    .font(.largeTitle)
//                    .bold()
//                    .foregroundColor(Color("Dark Blue"))
//
//                // Group and Date
//                HStack {
//                    Text("Group: ")
//                        .font(.headline)
//                        .foregroundColor(Color("Light Orange"))
//                    Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                        .font(.headline)
//                        .foregroundColor(Color("Dark Blue"))
//                }
//                HStack {
//                    Text("Dropped on: ")
//                        .font(.subheadline)
//                        .foregroundColor(Color("Light Orange"))
//                    Text("\(formattedDate(breadcrumb.dateDropped))")
//                        .font(.subheadline)
//                        .foregroundColor(Color("Dark Blue"))
//                }
//
//                // Latitude and Longitude
//                HStack {
//                    Text("Latitude: ")
//                        .foregroundColor(Color("Light Orange"))
//                    Text("\(breadcrumb.latitude)")
//                        .foregroundColor(Color("Dark Blue"))
//                }
//                HStack {
//                    Text("Longitude: ")
//                        .foregroundColor(Color("Light Orange"))
//                    Text("\(breadcrumb.longitude)")
//                        .foregroundColor(Color("Dark Blue"))
//                }
//
//                // Tap-to-Fullscreen Image
//                if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                    Button(action: {
//                        showFullScreenImage.toggle()
//                    }) {
//                        Image(uiImage: image)
//                            .resizable()
//                            .scaledToFit()
//                            .frame(maxWidth: .infinity, maxHeight: 300)
//                            .cornerRadius(10)
//                            .padding()
//                    }
//                } else {
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(height: 300)
//                        .cornerRadius(10)
//                        .overlay(
//                            Text("No Image Available")
//                                .font(.headline)
//                                .foregroundColor(.gray)
//                        )
//                        .padding()
//                }
//
//                // Notes Section
//                Text("Notes:")
//                    .font(.headline)
//                    .foregroundColor(Color("Light Orange"))
//                    .padding(.top)
//                Text(breadcrumb.note ?? "No Notes")
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding()
//
//                // Navigate to MapView
//                NavigationLink(
//                    destination: BreadcrumbMapView(
//                        latitude: breadcrumb.latitude,
//                        longitude: breadcrumb.longitude,
//                        name: breadcrumb.name ?? "Location"
//                    )
//                ) {
//                    Text("View on Map")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Light Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .cornerRadius(10)
//                }
//                .padding()
//            }
//        }
//        .padding()
//        .background(.white).ignoresSafeArea() // Dynamic background color
//        .navigationTitle("Crumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            // Edit Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: EditBreadcrumbView(breadcrumb: breadcrumb)) {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 20))
//                        .foregroundColor(Color("Light Orange")) // Dynamic toolbar icon color
//                }
//            }
//
//            // Favorite Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 20))
//                        .foregroundColor(breadcrumb.isFavorite ? .red : .gray)
//                }
//            }
//        }
//        .sheet(isPresented: $showFullScreenImage) {
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                FullScreenImageView(image: image)
//            }
//        }
//    }
//
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save() // Save changes to Core Data
//            print("Favorite status updated to: \(breadcrumb.isFavorite)")
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//
//    // MARK: - Helper Functions
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}


//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var colorSchemeManager: ColorSchemeManager // Access color scheme
//    @Environment(\.colorScheme) var colorScheme // Detect Light/Dark Mode
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 10) {
//                // Breadcrumb Name
//                Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                    .font(.largeTitle)
//                    .bold()
//                    .foregroundColor(Color("Dark Blue"))
//
//                // Group and Date
//                HStack {
//                    Text("Group: ")
//                        .font(.headline)
//                        .foregroundColor(foregroundColor)
//                    Text("\(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                        .font(.headline)
//                        .foregroundColor(Color("Dark Blue"))
//                }
//                HStack {
//                    Text("Dropped on: ")
//                        .font(.subheadline)
//                        .foregroundColor(foregroundColor)
//                    Text("\(formattedDate(breadcrumb.dateDropped))")
//                        .font(.subheadline)
//                        .foregroundColor(Color("Dark Blue"))
//                }
//
//                // Latitude and Longitude
//                HStack {
//                    Text("Latitude: ")
//                        .foregroundColor(foregroundColor)
//                    Text("\(breadcrumb.latitude)")
//                        .foregroundColor(Color("Dark Blue"))
//                }
//                HStack {
//                    Text("Longitude: ")
//                        .foregroundColor(foregroundColor)
//                    Text("\(breadcrumb.longitude)")
//                        .foregroundColor(Color("Dark Blue"))
//                }
//
//                ZoomableImage(image: loadImage(from: breadcrumb.photoURL))
//                    .frame(maxWidth: .infinity, maxHeight: 300) // Constrain size
//                    .cornerRadius(10)
//                    .padding()
//
//                // Notes Section
//                Text("Notes:")
//                    .font(.headline)
//                    .foregroundColor(foregroundColor)
//                    .padding(.top)
//                Text(breadcrumb.note ?? "No Notes")
//                    .foregroundColor(Color("Dark Blue"))
//                    .padding()
//
//                // Navigate to MapView
//                NavigationLink(
//                    destination: BreadcrumbMapView(
//                        latitude: breadcrumb.latitude,
//                        longitude: breadcrumb.longitude,
//                        name: breadcrumb.name ?? "Location"
//                    )
//                ) {
//                    Text("View on Map")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(buttonBackgroundColor)
//                        .foregroundColor(buttonForegroundColor)
//                        .cornerRadius(10)
//                }
//                .padding()
//            }
//        }
//        .padding()
//        .background(backgroundColor.ignoresSafeArea()) // Dynamic background color
//        .navigationTitle("Breadcrumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            // Edit Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: EditBreadcrumbView(breadcrumb: breadcrumb)) {
//                    Image(systemName: "pencil")
//                        .font(.title2)
//                        .foregroundColor(foregroundColor) // Dynamic toolbar icon color
//                }
//            }
//
//            // Favorite Button
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: toggleFavoriteStatus) {
//                    Image(systemName: breadcrumb.isFavorite ? "heart.fill" : "heart")
//                        .font(.title3)
//                        .foregroundColor(breadcrumb.isFavorite ? .red : foregroundColor)
//                }
//            }
//        }
//    }
//
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save() // Save changes to Core Data
//            print("Favorite status updated to: \(breadcrumb.isFavorite)")
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//    
//    private func loadImage(from fileName: String?) -> UIImage? {
//        guard let fileName = fileName else { return nil }
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//
//    // MARK: - Dynamic Colors
//    private var foregroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.light : colorSchemeManager.currentScheme.dark
//    }
//
//    private var backgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    private var buttonBackgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.dark : colorSchemeManager.currentScheme.light
//    }
//
//    private var buttonForegroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    // MARK: - Helper Functions
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
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


//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var colorSchemeManager: ColorSchemeManager // Access color scheme
//    @Environment(\.colorScheme) var colorScheme // Detect Light/Dark Mode
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 10) {
//                // Breadcrumb Name
//                Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                    .font(.largeTitle)
//                    .bold()
//                    .foregroundColor(foregroundColor)
//
//                // Group and Date
//                Text("Group: \(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                    .font(.headline)
//                    .foregroundColor(foregroundColor)
//
//                Text("Dropped on: \(formattedDate(breadcrumb.dateDropped))")
//                    .font(.subheadline)
//                    .foregroundColor(foregroundColor)
//
//                // Latitude and Longitude
//                Text("Latitude: \(breadcrumb.latitude)")
//                    .foregroundColor(foregroundColor)
//                Text("Longitude: \(breadcrumb.longitude)")
//                    .foregroundColor(foregroundColor)
//
//                // Pinch-to-Zoom Image
//                if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                    ZoomableImage(image: image)
//                        .frame(height: 300)
//                        .cornerRadius(10)
//                        .padding()
//                }
//
//                // Notes Section
//                Text("Notes:")
//                    .font(.headline)
//                    .foregroundColor(foregroundColor)
//                    .padding(.top)
//                Text(breadcrumb.note ?? "No Notes")
//                    .foregroundColor(foregroundColor)
//                    .padding()
//
//                // Favorite Button
//                Button(action: toggleFavoriteStatus) {
//                    HStack {
//                        Image(systemName: breadcrumb.isFavorite ? "star.fill" : "star")
//                            .foregroundColor(breadcrumb.isFavorite ? .yellow : .gray)
//                        Text(breadcrumb.isFavorite ? "Remove from Favorites" : "Mark as Favorite")
//                            .foregroundColor(foregroundColor)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(buttonBackgroundColor)
//                    .cornerRadius(10)
//                }
//                .padding()
//
//                // Navigate to MapView
//                NavigationLink(
//                    destination: BreadcrumbMapView(
//                        latitude: breadcrumb.latitude,
//                        longitude: breadcrumb.longitude,
//                        name: breadcrumb.name ?? "Location"
//                    )
//                ) {
//                    Text("View on Map")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(buttonBackgroundColor)
//                        .foregroundColor(buttonForegroundColor)
//                        .cornerRadius(10)
//                }
//                .padding()
//            }
//        }
//        .padding()
//        .background(backgroundColor.ignoresSafeArea()) // Dynamic background color
//        .navigationTitle("Breadcrumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: EditBreadcrumbView(breadcrumb: breadcrumb)) {
//                    Image(systemName: "pencil")
//                        .font(.title2)
//                        .foregroundColor(foregroundColor) // Dynamic toolbar icon color
//                }
//            }
//        }
//    }
//
//    // MARK: - Toggle Favorite Status
//    private func toggleFavoriteStatus() {
//        breadcrumb.isFavorite.toggle()
//        do {
//            try viewContext.save() // Save changes to Core Data
//            print("Favorite status updated to: \(breadcrumb.isFavorite)")
//        } catch {
//            print("Failed to update favorite status: \(error.localizedDescription)")
//        }
//    }
//
//    // MARK: - Dynamic Colors
//    private var foregroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.light : colorSchemeManager.currentScheme.dark
//    }
//
//    private var backgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    private var buttonBackgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.dark : colorSchemeManager.currentScheme.light
//    }
//
//    private var buttonForegroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    // MARK: - Helper Functions
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
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


//import SwiftUI
//
//struct BreadcrumbDetailView: View {
//    @ObservedObject var breadcrumb: Breadcrumb
//    @State private var imageScale: CGFloat = 1.0
//
//    @EnvironmentObject var colorSchemeManager: ColorSchemeManager // Access color scheme
//    @Environment(\.colorScheme) var colorScheme // Detect Light/Dark Mode
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 10) {
//                // Breadcrumb Name
//                Text(breadcrumb.name ?? "Unnamed Breadcrumb")
//                    .font(.largeTitle)
//                    .bold()
//                    .foregroundColor(foregroundColor)
//
//                // Group and Date
//                Text("Group: \(breadcrumb.crmGroup?.groupName ?? "N/A")")
//                    .font(.headline)
//                    .foregroundColor(foregroundColor)
//
//                Text("Dropped on: \(formattedDate(breadcrumb.dateDropped))")
//                    .font(.subheadline)
//                    .foregroundColor(foregroundColor)
//
//                // Latitude and Longitude
//                Text("Latitude: \(breadcrumb.latitude)")
//                    .foregroundColor(foregroundColor)
//                Text("Longitude: \(breadcrumb.longitude)")
//                    .foregroundColor(foregroundColor)
//
//                // Pinch-to-Zoom Image
//                if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                    ZoomableImage(image: image)
//                        .frame(height: 300)
//                        .cornerRadius(10)
//                        .padding()
//                }
//
//                // Notes Section
//                Text("Notes:")
//                    .font(.headline)
//                    .foregroundColor(foregroundColor)
//                    .padding(.top)
//                Text(breadcrumb.note ?? "No Notes")
//                    .foregroundColor(foregroundColor)
//                    .padding()
//
//                // Navigate to MapView
//                NavigationLink(
//                    destination: BreadcrumbMapView(
//                        latitude: breadcrumb.latitude,
//                        longitude: breadcrumb.longitude,
//                        name: breadcrumb.name ?? "Location"
//                    )
//                ) {
//                    Text("View on Map")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(buttonBackgroundColor)
//                        .foregroundColor(buttonForegroundColor)
//                        .cornerRadius(10)
//                }
//                .padding()
//            }
//        }
//        .padding()
//        .background(backgroundColor.ignoresSafeArea()) // Dynamic background color
//        .navigationTitle("Breadcrumb Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: EditBreadcrumbView(breadcrumb: breadcrumb)) {
//                    Image(systemName: "pencil")
//                        .font(.title2)
//                        .foregroundColor(foregroundColor) // Dynamic toolbar icon color
//                }
//            }
//        }
//    }
//
//    // MARK: - Dynamic Colors
//    private var foregroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.light : colorSchemeManager.currentScheme.dark
//    }
//
//    private var backgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    private var buttonBackgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.dark : colorSchemeManager.currentScheme.light
//    }
//
//    private var buttonForegroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    // MARK: - Helper Functions
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "Unknown Date" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
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


