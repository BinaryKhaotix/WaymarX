//
//  RecentBreadcrumbsView.swift
//  Iron Lady
//
//  Group Import/Export enabled (keeps original layout/FNF)
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
    @State private var selectedTab: Tab = .home

    private var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
    }

    // Filter + explicitly sort (newest first) + cap.
    private var recentPins: [Breadcrumb] {
        allBreadcrumbs
            .filter { crumb in
                guard !crumb.isWantToGo else {
                    return false
                }

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

            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                ScrollView {

                    VStack(alignment: .leading, spacing: 10) {

                        Text("Recent Pins")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        if recentPins.isEmpty {

                            VStack(spacing: 12) {

                                Image(systemName: "mappin.slash")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.gray)

                                Text("No recent pins.")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                Text("Pins from the last \(daysBack) days will show here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 320
                            )
                            .padding(.top, 40)

                        } else {

                            LazyVGrid(
                                columns: columns,
                                spacing: 10
                            ) {

                                ForEach(
                                    recentPins,
                                    id: \.objectID
                                ) { breadcrumb in

                                    Button {

                                        navigationModel.pushBreadcrumbDetail(
                                            in: recentPins,
                                            selected: breadcrumb
                                        )

                                    } label: {

                                        FavoriteCrumbTile(
                                            breadcrumb: breadcrumb,
                                            showHeart: breadcrumb.isFavorite
                                        )
                                        .environmentObject(
                                            locationManager
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    .contextMenu {

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
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 10)
                }

                // MARK: - AdMob Banner

                WaymarXBannerView()

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

        .navigationTitle("Recent Pins")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()

        .toolbar {

            ToolbarItem(
                placement: .navigationBarLeading
            ) {

                Button {

                    navigationModel.path = [.dashboard]

                } label: {

                    HStack(spacing: 6) {

                        Image(
                            systemName: "chevron.left"
                        )

                        Text("Dashboard")
                    }
                    .foregroundStyle(.white)
                }
            }

            ToolbarItem(
                placement: .navigationBarTrailing
            ) {

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
}


