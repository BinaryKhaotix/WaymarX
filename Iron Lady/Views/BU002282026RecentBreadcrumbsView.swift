//
//  RecentBreadcrumbsView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/16/26.
//
import SwiftUI
import CoreData

public struct RecentBreadcrumbsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var locationManager: LocationManager

    @FetchRequest(
        entity: Breadcrumb.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
    ) private var allBreadcrumbs: FetchedResults<Breadcrumb>

    private let daysBack: Int = 30
    private let maxPins: Int = 100

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    // Group Import/Export UI
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingImportPicker = false
    @State private var transferError: String?

    private var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
    }

    // Filter + explicitly sort (newest first) + cap.
    private var recentPins: [Breadcrumb] {
        allBreadcrumbs
            .filter { crumb in
                guard let d = crumb.dateDropped else { return false }
                return d >= cutoffDate
            }
            .sorted { (a, b) in
                let da = a.dateDropped ?? .distantPast
                let db = b.dateDropped ?? .distantPast
                return da > db
            }
            .prefix(maxPins)
            .map { $0 }
    }

    public var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {

                    Text("Recent Pins")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.black)
                        .padding(.horizontal)

                    if recentPins.isEmpty {
                        EmptyRecentPinsView(daysBack: daysBack)
                            .frame(maxWidth: .infinity, minHeight: 320)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(recentPins, id: \.objectID) { breadcrumb in
                                Button {
                                    navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
                                } label: {
                                    RecentCrumbTile(breadcrumb: breadcrumb)
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
                            }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("Recent Pins")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    navigationModel.path = [.dashboard]
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Dashboard")
                    }
                    .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingImportPicker = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
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

    }
}


// MARK: - Tile wrapper that adds "time ago" + conditional heart
private struct RecentCrumbTile: View {
    let breadcrumb: Breadcrumb

    private var droppedDate: Date {
        breadcrumb.dateDropped ?? Date()
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Base tile (photo + name). Heart handled here, not inside the base tile.
            FavoriteCrumbTile(breadcrumb: breadcrumb, showHeart: false)

            // Bottom-left "x time ago"
            Text(droppedDate, style: .relative)
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            // Only show heart if it truly is a favorite
            if breadcrumb.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(6)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingImportPicker = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
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

    }
}


// MARK: - Empty State
private struct EmptyRecentPinsView: View {
    let daysBack: Int

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Nothing in the last \(daysBack) days")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)

                Text("Get out and see something ☹️")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}









// 022626 bsfore group crumb export/import modifications
//
//import SwiftUI
//import CoreData
//
//public struct RecentBreadcrumbsView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
//    ) private var allBreadcrumbs: FetchedResults<Breadcrumb>
//
//    private let daysBack: Int = 30
//    private let maxPins: Int = 100
//
//    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
//
//    private var cutoffDate: Date {
//        Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
//    }
//
//    // Filter + explicitly sort (newest first) + cap.
//    private var recentPins: [Breadcrumb] {
//        allBreadcrumbs
//            .filter { crumb in
//                guard let d = crumb.dateDropped else { return false }
//                return d >= cutoffDate
//            }
//            .sorted { (a, b) in
//                let da = a.dateDropped ?? .distantPast
//                let db = b.dateDropped ?? .distantPast
//                return da > db
//            }
//            .prefix(maxPins)
//            .map { $0 }
//    }
//
//    public var body: some View {
//        ZStack {
//            Color(.systemGroupedBackground).ignoresSafeArea()
//
//            ScrollView {
//                VStack(alignment: .leading, spacing: 10) {
//
//                    Text("Recent Pins")
//                        .font(.title2)
//                        .bold()
//                        .foregroundColor(.black)
//                        .padding(.horizontal)
//
//                    if recentPins.isEmpty {
//                        EmptyRecentPinsView(daysBack: daysBack)
//                            .frame(maxWidth: .infinity, minHeight: 320)
//                            .padding(.top, 40)
//                    } else {
//                        LazyVGrid(columns: columns, spacing: 10) {
//                            ForEach(recentPins, id: \.objectID) { breadcrumb in
//                                Button {
//                                    navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                                } label: {
//                                    RecentCrumbTile(breadcrumb: breadcrumb)
//                                }
//                                .buttonStyle(.plain)
//                            }
//                        }
//                        .padding(.horizontal)
//                    }
//                }
//                .padding(.vertical, 10)
//            }
//        }
//        .navigationTitle("Recent Pins")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden()
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button {
//                    navigationModel.path = [.dashboard]
//                } label: {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left")
//                        Text("Dashboard")
//                    }
//                    .foregroundStyle(.white)
//                }
//            }
//        }
//    }
//}
//
//
//// MARK: - Tile wrapper that adds "time ago" + conditional heart
//private struct RecentCrumbTile: View {
//    let breadcrumb: Breadcrumb
//
//    private var droppedDate: Date {
//        breadcrumb.dateDropped ?? Date()
//    }
//
//    var body: some View {
//        ZStack(alignment: .bottomLeading) {
//            // Base tile (photo + name). Heart handled here, not inside the base tile.
//            FavoriteCrumbTile(breadcrumb: breadcrumb, showHeart: false)
//
//            // Bottom-left "x time ago"
//            Text(droppedDate, style: .relative)
//                .font(.caption2)
//                .foregroundStyle(.white)
//                .padding(.horizontal, 6)
//                .padding(.vertical, 4)
//                .background(.ultraThinMaterial, in: Capsule())
//                .padding(6)
//        }
//        .overlay(alignment: .topTrailing) {
//            // Only show heart if it truly is a favorite
//            if breadcrumb.isFavorite {
//                Image(systemName: "heart.fill")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundStyle(.red)
//                    .padding(6)
//                    .background(.ultraThinMaterial, in: Circle())
//                    .padding(6)
//            }
//        }
//    }
//}
//
//
//// MARK: - Empty State
//private struct EmptyRecentPinsView: View {
//    let daysBack: Int
//
//    var body: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "mappin.slash")
//                .font(.system(size: 52, weight: .regular))
//                .foregroundStyle(.secondary)
//
//            VStack(spacing: 6) {
//                Text("Nothing in the last \(daysBack) days")
//                    .font(.system(.title3, design: .rounded))
//                    .fontWeight(.semibold)
//
//                Text("Get out and see something ☹️")
//                    .font(.system(.subheadline, design: .rounded))
//                    .foregroundStyle(.secondary)
//            }
//            .multilineTextAlignment(.center)
//        }
//        .padding(40)
//    }
//}




//import SwiftUI
//import CoreData
//
//public struct RecentBreadcrumbsView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//
//    // Pull a reasonably sized superset, then filter to "recent" reliably.
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
//    ) private var allBreadcrumbs: FetchedResults<Breadcrumb>
//
//    private let daysBack: Int = 30     // <-- set "recent" window here
//    private let maxPins: Int = 100
//
//    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
//
//    private var cutoffDate: Date {
//        Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
//    }
//
//    // This is the ONLY list the UI should render.
//    private var recentPins: [Breadcrumb] {
//        allBreadcrumbs
//            .filter { crumb in
//                guard let d = crumb.dateDropped else { return false }
//                return d >= cutoffDate
//            }
//            .prefix(maxPins)
//            .map { $0 }
//    }
//
//    public var body: some View {
//        ZStack {
//            Color(.systemGroupedBackground).ignoresSafeArea()
//
//            ScrollView {
//                VStack(alignment: .leading, spacing: 10) {
//
//                    Text("Recent Pins")
//                        .font(.title2)
//                        .bold()
//                        .foregroundColor(.black)
//                        .padding(.horizontal)
//
//                    if recentPins.isEmpty {
//                        EmptyRecentPinsView(daysBack: daysBack)
//                            .frame(maxWidth: .infinity, minHeight: 320)
//                            .padding(.top, 40)
//                    } else {
//                        LazyVGrid(columns: columns, spacing: 10) {
//                            ForEach(recentPins, id: \.objectID) { breadcrumb in
//                                Button {
//                                    navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                                } label: {
//                                    FavoriteCrumbTile(breadcrumb: breadcrumb)
//                                }
//                                .buttonStyle(.plain)
//                            }
//                        }
//                        .padding(.horizontal)
//                    }
//                }
//                .padding(.vertical, 10)
//            }
//        }
//        .navigationTitle("Recent Pins")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden()
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button {
//                    navigationModel.path = [.dashboard]
//                } label: {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left")
//                        Text("Dashboard")
//                    }
//                    .foregroundStyle(.white)
//                }
//            }
//        }
//    }
//}
//
//
//// MARK: - Empty State
//private struct EmptyRecentPinsView: View {
//    let daysBack: Int
//
//    var body: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "mappin.slash")
//                .font(.system(size: 52, weight: .regular))
//                .foregroundStyle(.secondary)
//
//            VStack(spacing: 6) {
//                Text("Nothing in the last \(daysBack) days")
//                    .font(.system(.title3, design: .rounded))
//                    .fontWeight(.semibold)
//
//                Text("Get out and see something ☹️")
//                    .font(.system(.subheadline, design: .rounded))
//                    .foregroundStyle(.secondary)
//            }
//            .multilineTextAlignment(.center)
//        }
//        .padding(40)
//    }
//}



//import SwiftUI
//import CoreData
//
//public struct RecentBreadcrumbsView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var navigationModel: NavigationModel
//    @EnvironmentObject var locationManager: LocationManager
//
//    // Pull a reasonably sized superset, then filter to "recent" reliably.
//    @FetchRequest(
//        entity: Breadcrumb.entity(),
//        sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
//    ) private var allBreadcrumbs: FetchedResults<Breadcrumb>
//
//    private let daysBack: Int = 30     // <-- set "recent" window here
//    private let maxPins: Int = 100
//
//    private var cutoffDate: Date {
//        Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
//    }
//
//    // This is the ONLY list the UI should render.
//    private var recentPins: [Breadcrumb] {
//        allBreadcrumbs
//            .filter { crumb in
//                guard let d = crumb.dateDropped else { return false }
//                return d >= cutoffDate
//            }
//            .prefix(maxPins)
//            .map { $0 }
//    }
//
//    public var body: some View {
//        ZStack {
//            Color(.systemGroupedBackground).ignoresSafeArea()
//
//            ScrollView {
//                if recentPins.isEmpty {
//                    EmptyRecentPinsView(daysBack: daysBack)
//                        .frame(maxWidth: .infinity, minHeight: 320)
//                        .padding(.top, 40)
//                } else {
//                    LazyVStack(spacing: 12) {
//                        ForEach(recentPins, id: \.objectID) { breadcrumb in
//                            Button {
//                                navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                            } label: {
//                                RecentPinRow(breadcrumb: breadcrumb)
//                                    .contentShape(Rectangle())
//                            }
//                            .buttonStyle(.plain)
//                        }
//                    }
//                    .padding(16)
//                }
//            }
//        }
//        .navigationTitle("Recent Pins")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden()
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button {
//                    navigationModel.path = [.dashboard]
//                } label: {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left")
//                        Text("Dashboard")
//                    }
//                    .foregroundStyle(.white)
//                }
//            }
//        }
//    }
//}
//
//
//// MARK: - Empty State
//private struct EmptyRecentPinsView: View {
//    let daysBack: Int
//
//    var body: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "mappin.slash")
//                .font(.system(size: 52, weight: .regular))
//                .foregroundStyle(.secondary)
//
//            VStack(spacing: 6) {
//                Text("Nothing in the last \(daysBack) days")
//                    .font(.system(.title3, design: .rounded))
//                    .fontWeight(.semibold)
//
//                Text("Get out and see something ☹️")
//                    .font(.system(.subheadline, design: .rounded))
//                    .foregroundStyle(.secondary)
//            }
//            .multilineTextAlignment(.center)
//        }
//        .padding(40)
//    }
//}
//
//
//// MARK: - Row UI
//private struct RecentPinRow: View {
//    let breadcrumb: Breadcrumb
//
//    private var displayName: String {
//        let name = (breadcrumb.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
//        return name.isEmpty ? "Unnamed Pin" : name
//    }
//
//    private var displayDate: Date {
//        breadcrumb.dateDropped ?? Date()
//    }
//
//    var body: some View {
//        HStack(spacing: 12) {
//            Image(systemName: "mappin.and.ellipse")
//                .font(.system(size: 18, weight: .semibold))
//                .foregroundStyle(Color("Dark Orange"))
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(displayName)
//                    .font(.caption)
//                    .foregroundStyle(.white, .black)
//                    .bold()
//                    .multilineTextAlignment(.center)
//                    .lineLimit(3)
//                    .padding(2)
//                    .cornerRadius(5)
//                    .padding(2) // Padding to keep the text away from tile edges
//
//                    //.font(.system(.headline, design: .rounded))
////                    .foregroundStyle(Color("Dark Blue"))
////                    .lineLimit(1)
//
//                Text(displayDate, style: .relative)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
//
//            Spacer()
//
//            Image(systemName: "chevron.right")
//                .font(.system(size: 12, weight: .semibold))
//                .foregroundStyle(.secondary)
//        }
//        .padding(14)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: 18, style: .continuous)
//                .fill(Color(.systemBackground))
//        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 18, style: .continuous)
//                .stroke(Color.black.opacity(0.07), lineWidth: 1)
//        )
//        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 5)
//    }
//}
