//
//  UnnamedCrumbsView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/12/24.
//
import SwiftUI
import CoreData

struct UnnamedCrumbsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
    @FetchRequest var unnamedBreadcrumbs: FetchedResults<Breadcrumb>

    // Group Import/Export UI
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingImportPicker = false
    @State private var transferError: String?

    init() {
        self._unnamedBreadcrumbs = FetchRequest(
            entity: Breadcrumb.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
            predicate: NSPredicate(format: "name == %@", "Unnamed Pin")
        )
    }
    
    var body: some View {
        List(unnamedBreadcrumbs, id: \.self) { breadcrumb in
            Button(action: {
                navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb)) // Append destination to navigation path
            }) {
                BreadcrumbTileView(breadcrumb: breadcrumb)
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
                    .listRowBackground(Color(.white)) // Dynamic background for list rows
            }
        }
        .background(.white).ignoresSafeArea() // Dynamic view background
        .navigationTitle("Unnamed Pins")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Unnamed Pins")
                    .font(.headline)
                    .foregroundColor(Color("Dark Orange")) // Dynamic navigation title color
            }
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
                Button {
                    showingImportPicker = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .foregroundColor(.white)
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










// 022626 before group crumb export/import modifications
//
//import SwiftUI
//
//struct UnnamedCrumbsView: View {
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//    @FetchRequest var unnamedBreadcrumbs: FetchedResults<Breadcrumb>
//
//    init() {
//        self._unnamedBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "name == %@", "Unnamed Pin")
//        )
//    }
//
//    var body: some View {
//        List(unnamedBreadcrumbs, id: \.self) { breadcrumb in
//            Button(action: {
//                navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb)) // Append destination to navigation path
//            }) {
//                BreadcrumbTileView(breadcrumb: breadcrumb)
//                    .listRowBackground(Color(.white)) // Dynamic background for list rows
//            }
//        }
//        .background(.white).ignoresSafeArea() // Dynamic view background
//        .navigationTitle("Unnamed Pins")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text("Unnamed Pins")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange")) // Dynamic navigation title color
//            }
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
//    }
//}


//import SwiftUI
//
//struct UnnamedCrumbsView: View {
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//    @FetchRequest var unnamedBreadcrumbs: FetchedResults<Breadcrumb>
//
//    init() {
//        self._unnamedBreadcrumbs = FetchRequest(
//            entity: Breadcrumb.entity(),
//            sortDescriptors: [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)],
//            predicate: NSPredicate(format: "name == %@", "Unnamed")
//        )
//    }
//
//    var body: some View {
//        List(unnamedBreadcrumbs, id: \.self) { breadcrumb in
//            NavigationLink(destination: BreadcrumbDetailView(breadcrumb: breadcrumb)) {
//                BreadcrumbTileView(breadcrumb: breadcrumb)
//                    .listRowBackground(Color(.white)) // Dynamic background for list rows
//            }
//        }
//        .background(.white).ignoresSafeArea() // Dynamic view background
//        .navigationTitle("Unnamed Crumbz")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text("Unnamed Crumbz")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange")) // Dynamic navigation title color
//            }
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
//        }
//    }
//
//}
