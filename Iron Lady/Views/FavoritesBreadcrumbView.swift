//
//  FavoritesBreadcrumbView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/24/25.
//
import SwiftUI

struct FavoritesBreadcrumbView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel

    let breadcrumbs: [Breadcrumb]
    let onTap: (Breadcrumb) -> Void


    // Group Import/Export UI
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingImportPicker = false
    @State private var transferError: String?
    @State private var selectedTab: Tab = .home
    
    private var regularFavorites: [Breadcrumb] {
        breadcrumbs.filter { breadcrumb in
            !breadcrumb.isWantToGo
        }
    }

    var body: some View {

        GeometryReader { geometry in

            let isLandscape =
                geometry.size.width > geometry.size.height

            let tileSize: CGFloat = 110
            let tileSpacing: CGFloat = 10
            let horizontalPadding: CGFloat = 32

            let usableWidth =
                geometry.size.width - horizontalPadding

            let columnCount = max(
                3,
                Int(
                    (usableWidth + tileSpacing) /
                    (tileSize + tileSpacing)
                )
            )

            let columns = Array(
                repeating: GridItem(
                    .fixed(tileSize),
                    spacing: tileSpacing
                ),
                count: columnCount
            )
            
            ZStack {
                
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    ScrollView {
                        
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("Favorite Pins")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.black)
                                .padding(.horizontal)
                            
                            if regularFavorites.isEmpty {
                                
                                VStack(spacing: 12) {
                                    
                                    Image(systemName: "heart.slash")
                                        .font(.system(size: 42))
                                        .foregroundStyle(.gray)
                                    
                                    Text("No favorites yet.")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Mark a pin as a favorite and it will show up here.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: 320
                                )
                                .padding(.horizontal)
                                .padding(.top, 40)
                                
                            } else {
                                
                                LazyVGrid(
                                    columns: columns,
                                    spacing: tileSpacing
                                ) {
                                    
                                    ForEach(
                                        regularFavorites,
                                        id: \.objectID
                                    ) { breadcrumb in
                                        
                                        Button {
                                            
                                            onTap(breadcrumb)
                                            
                                        } label: {
                                            
                                            FavoriteCrumbTile(
                                                breadcrumb: breadcrumb
                                            )
                                            .frame(
                                                width: tileSize,
                                                height: tileSize
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

        .navigationTitle("Favorites")
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
                    .foregroundColor(.white)
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
