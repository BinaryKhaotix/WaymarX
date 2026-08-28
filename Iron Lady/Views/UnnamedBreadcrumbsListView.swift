//
//  UnnamedBreadcrumbsListView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/12/24.
//

import SwiftUI
import CoreData

struct UnnamedBreadcrumbsListView: View {
    @EnvironmentObject var navigationModel: NavigationModel // For navigation
    @State private var searchQuery: String = "" // For dynamic search input
    @State private var selectedTab: Tab = .home // Track the selected tab
    @State private var filterOption: FilterOption = .name // Default filter option

    let breadcrumbs: [Breadcrumb]

    // Filter Options
    enum FilterOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case dateAdded = "Date Added"
        case favorites = "Favorites"

        var id: String { self.rawValue }
    }

    // Filtered Breadcrumbs Based on Filter Option and Search Query
    var filteredBreadcrumbs: [Breadcrumb] {
        var results: [Breadcrumb]

        // Apply filter
        switch filterOption {
        case .name:
            results = breadcrumbs.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .dateAdded:
            results = breadcrumbs.sorted { ($0.dateDropped ?? Date()) > ($1.dateDropped ?? Date()) }
        case .favorites:
            results = breadcrumbs.filter { $0.isFavorite }
        }

        // Apply search query
        if searchQuery.isEmpty {
            return results
        } else {
            return results.filter { breadcrumb in
                let query = searchQuery.lowercased()
                return (breadcrumb.name ?? "").lowercased().contains(query) ||
                       formattedDate(breadcrumb.dateDropped).lowercased().contains(query)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            TextField("Search...", text: $searchQuery)
                .padding(10)
                .background(Color("Dark Blue").opacity(0.7))
                .foregroundColor(Color("Light Orange").opacity(0.9))
                .cornerRadius(10)
                .frame(height: 45)
                .padding(.horizontal)
                .padding(.top, 10)

            // Scrollable List of Breadcrumbs
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(filteredBreadcrumbs, id: \Breadcrumb.self) { breadcrumb in
                        Button(action: {
                            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
                        }) {
                            BreadcrumbTileView(breadcrumb: breadcrumb)
                        }
                        .buttonStyle(PlainButtonStyle()) // Preserve original styling
                    }
                }
                .padding()
            }

            // Bottom Navigation Bar
            BottomNavigationBar(
                selectedTab: $selectedTab,
                onHome: {
                    navigationModel.path = [.dashboard]
                },
                onDropCrumb: {
                    navigationModel.path.append(.addBreadcrumb)
                },
                onMap: {
                    navigationModel.path.append(.groupCrumbMap(groupBreadcrumbs: breadcrumbs))
                },
                onGroups: {
                    navigationModel.path.append(.groupsList)
                },
                onProfile: {
                    navigationModel.path.append(.editProfile)
                },
                showHome: true,        // Show Home button
                showDropCrumb: true,  // Show Drop Crumb button
                showMap: false,       // Hide Map button
                showGroups: true,     // Show Groups button
                showProfile: true     // Show Profile button
            )
            .frame(height: 60)
        }
        .navigationTitle("Unnamed Pins")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Back Button
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

            // Filter Menu
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Filter", selection: $filterOption) {
                        ForEach(FilterOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .foregroundColor(Color("Dark Orange"))
                            .font(.title2)
                    }
                }
            }
        }
    }

    // MARK: - Format Date Helper
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}




//import SwiftUI
//import CoreData
//
//struct UnnamedBreadcrumbsListView: View {
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//    @State private var searchQuery: String = "" // For dynamic search input
//    @State private var selectedTab: Tab = .home // Track the selected tab
//
//    let breadcrumbs: [Breadcrumb]
//
//    // Filtered Breadcrumbs Based on Search Query
//    var filteredBreadcrumbs: [Breadcrumb] {
//        if searchQuery.isEmpty {
//            return breadcrumbs
//        } else {
//            return breadcrumbs.filter { breadcrumb in
//                let query = searchQuery.lowercased()
//                return (breadcrumb.name ?? "").lowercased().contains(query) ||
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
//                .background(Color("Dark Blue").opacity(0.7))
//                .foregroundColor(Color("Light Orange").opacity(0.9))
//                .cornerRadius(10)
//                .frame(height: 45)
//                .padding(.horizontal)
//                .padding(.top, 10)
//
//            // Breadcrumb List
//            List {
//                ForEach(filteredBreadcrumbs, id: \Breadcrumb.self) { breadcrumb in
//                    NavigationLink(destination: BreadcrumbDetailView(breadcrumb: breadcrumb)) {
//                        BreadcrumbRowView(breadcrumb: breadcrumb)
//                            .padding(.leading)
//                    }
//                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
//                    .listRowBackground(Color.clear)
//                }
//            }
//            .listStyle(PlainListStyle())
//            .navigationTitle("Unnamed Crumbz")
//            .navigationBarTitleDisplayMode(.inline)
//            .navigationBarBackButtonHidden(true)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
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
//                showMap: false,         // Show Map button
//                showGroups: true,      // Show Groups button
//                showProfile: true     // Show Profile button
//            )
//            .frame(height: 60)
//        }
//        .background(Color.white.ignoresSafeArea())
//    }
//
//    // MARK: - Format Date Helper
//    private func formattedDate(_ date: Date?) -> String {
//        guard let date = date else { return "" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        return formatter.string(from: date)
//    }
//}

//import SwiftUI
//
//struct UnnamedBreadcrumbsListView: View {
//    let breadcrumbs: [Breadcrumb]
//
//    var body: some View {
//        List(breadcrumbs, id: \.self) { breadcrumb in
//            NavigationLink(destination: BreadcrumbDetailView(breadcrumb: breadcrumb)) {
//                VStack(alignment: .leading) {
//                    Text(breadcrumb.name ?? "Unnamed")
//                        .font(.headline)
//                        .foregroundColor(Color("Dark Orange")) // Dynamic text color
//
//                    if let dateDropped = breadcrumb.dateDropped {
//                        Text(dateDropped, style: .date)
//                            .font(.subheadline)
//                            .foregroundColor(Color("Dark Blue"))
//                    }
//                }
//            }
//            .listRowBackground(Color.white.opacity(0.7)) // Dynamic background for list rows
//        }
//        .background(Color.white.ignoresSafeArea()) // Dynamic view background
//        .navigationTitle("Unnamed Breadcrumbs")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text("Unnamed Breadcrumbs")
//                    .font(.headline)
//            }
//        }
//    }
//}
