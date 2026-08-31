//
//  WantToGoListView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/28/26.
//

import SwiftUI
import CoreData

struct WantToGoListView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel
    
    @FetchRequest private var wantToGoBreadcrumbs: FetchedResults<Breadcrumb>
    
    @State private var selectedBreadcrumb: Breadcrumb?
    @State private var showDeleteAlert = false
    
    @State private var breadcrumbToPromote: Breadcrumb?
    @State private var showPromoteAlert = false
    
    init() {
        
        let request: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
        
        request.sortDescriptors = [
            NSSortDescriptor(
                keyPath: \Breadcrumb.wantToGoDate,
                ascending: false
            )
        ]
        
        request.predicate = NSPredicate(
            format: "isWantToGo == YES"
        )
        
        _wantToGoBreadcrumbs = FetchRequest(
            fetchRequest: request
        )
    }
    
    var body: some View {
        
        ZStack {
            
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if wantToGoBreadcrumbs.isEmpty {
                
                emptyState
                
            } else {
                
                listContent
            }
        }
        .navigationTitle("Want to Go")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(
            Color("Dark Blue"),
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
        
        .navigationTitle("Want to Go")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        
        .toolbarBackground(
            Color("Dark Blue"),
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        
        .toolbar {
            
            // Left: Back
            ToolbarItem(placement: .navigationBarLeading) {
                
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
            
            // Center: Title
            ToolbarItem(placement: .principal) {
                
                Text("Want to Go")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("Light Orange"))
            }
            
            // Right: Add
            ToolbarItem(placement: .navigationBarTrailing) {
                
                Button {
                    navigationModel.path.append(.wantToGoMap)
                } label: {
                    
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("Dark Orange"))
                }
            }
        }
        .alert(
            "Remove Destination?",
            isPresented: $showDeleteAlert
        ) {
            
            Button(
                "Remove",
                role: .destructive
            ) {
                
                removeSelectedDestination()
            }
            
            Button(
                "Cancel",
                role: .cancel
            ) {
                
                selectedBreadcrumb = nil
            }
            
        } message: {
            
            Text(
                "This will remove the destination from your Want to Go list."
            )
        }
        .alert(
            "Promote Pin?",
            isPresented: $showPromoteAlert
        ) {
            
            Button("Promote") {
                
                guard let breadcrumb =
                        breadcrumbToPromote
                else {
                    return
                }
                
                Task {
                    await WantToGoArrivalManager
                        .shared
                        .markAsVisited(
                            breadcrumb
                        )
                    
                    breadcrumbToPromote = nil
                }
            }
            
            Button(
                "Cancel",
                role: .cancel
            ) {
                breadcrumbToPromote = nil
            }
            
        } message: {
            
            Text(
                "This will move the destination from Want to Go into your regular pins."
            )
        }
    }
    
    
    private func configureNavigationBarAppearance() {
        
        let appearance = UINavigationBarAppearance()
        
        appearance.configureWithOpaqueBackground()
        
        appearance.backgroundColor = UIColor(named: "Dark Blue")
        
        appearance.titleTextAttributes = [
            .foregroundColor:
                UIColor(named: "Light Orange") ?? .white
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - List
    
    private var listContent: some View {
        
        ScrollView {
            
            LazyVStack(spacing: 12) {
                
                ForEach(
                    wantToGoBreadcrumbs,
                    id: \.objectID
                ) { breadcrumb in
                    
                    destinationRow(
                        breadcrumb
                    )
                }
            }
            .padding()
        }
    }
    
    
    // MARK: - Row
    
    private func destinationRow(
        _ breadcrumb: Breadcrumb
    ) -> some View {
        
        Button {
            
            navigationModel.path.append(
                .breadcrumbDetail(
                    breadcrumb: breadcrumb
                )
            )
            
        } label: {
            
            HStack(spacing: 12) {
                
                destinationImage(
                    for: breadcrumb
                )
                .frame(
                    width: 74,
                    height: 74
                )
                .clipped()
                
                
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    
                    Text(
                        breadcrumb.name
                        ?? "Unnamed Destination"
                    )
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    
                    let subtitle =
                    locationText(
                        for: breadcrumb
                    )
                    
                    if !subtitle.isEmpty {
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(1)
                    }
                    
                    if let date =
                        breadcrumb.wantToGoDate {
                        
                        Text(
                            "Added \(date.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
                
                Spacer()
                
                Image(
                    systemName: "chevron.right"
                )
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                Color(
                    .secondarySystemBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        
        .contextMenu {
            
            Button {
                
                breadcrumbToPromote =
                breadcrumb
                
                showPromoteAlert =
                true
                
            } label: {
                
                Label(
                    "Promote Pin",
                    systemImage:
                        "arrow.up.circle.fill"
                )
            }
            
            
            Button(
                role: .destructive
            ) {
                
                selectedBreadcrumb =
                breadcrumb
                
                showDeleteAlert =
                true
                
            } label: {
                
                Label(
                    "Remove",
                    systemImage: "trash"
                )
            }
        }
    }
    
    @ViewBuilder
    private func destinationImage(
        for breadcrumb: Breadcrumb
    ) -> some View {
        
        if let photoFileName = breadcrumb.photoURL,
           !photoFileName.isEmpty,
           let documentsDirectory =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first {
            
            let fileURL =
            documentsDirectory.appendingPathComponent(
                photoFileName
            )
            
            if let uiImage =
                UIImage(
                    contentsOfFile: fileURL.path
                ) {
                
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 25,
                            style: .continuous
                        )
                    )
                
            } else {
                
                destinationPlaceholder
            }
            
        } else {
            
            destinationPlaceholder
        }
    }
    
    private var destinationPlaceholder: some View {
        
        ZStack {
            
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(
                Color(
                    .tertiarySystemBackground
                )
            )
            
            Image(
                systemName: "mappin.and.ellipse"
            )
            .font(.title2)
            .foregroundStyle(.red)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        
        VStack(spacing: 16) {
            
            Spacer()
            
            Image(
                systemName: "map"
            )
            .font(
                .system(size: 52)
            )
            .foregroundStyle(
                .secondary
            )
            
            Text(
                "Where do you want to go?"
            )
            .font(.title2)
            .fontWeight(.semibold)
            
            Text(
                "Search for a place you've always wanted to visit, or explore the map and save a destination."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            
            Button {
                
                navigationModel.path.append(
                    .wantToGoMap
                )
                
            } label: {
                
                Label(
                    "Add a Destination",
                    systemImage: "plus.circle.fill"
                )
                .fontWeight(.semibold)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Color("Dark Blue")
                )
                .foregroundStyle(.white)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
            }
            
            Spacer()
        }
        .padding()
    }
    
    
    // MARK: - Helpers
    
    private func locationText(
        for breadcrumb: Breadcrumb
    ) -> String {
        
        var parts: [String] = []
        
        if let city = breadcrumb.city,
           !city.isEmpty {
            
            parts.append(city)
        }
        
        if let state = breadcrumb.state,
           !state.isEmpty {
            
            parts.append(state)
        }
        
        return parts.joined(
            separator: ", "
        )
    }
    
    
    // MARK: - Remove
    
    private func removeSelectedDestination() {
        
        guard let breadcrumb =
                selectedBreadcrumb
        else {
            return
        }
        
        let breadcrumbID =
        breadcrumb.id
        
        viewContext.delete(
            breadcrumb
        )
        
        do {
            
            try viewContext.save()
            
        } catch {
            
            print(
                "Failed to remove Want to Go destination: \(error)"
            )
            
            return
        }
        
        selectedBreadcrumb =
        nil
        
        if let breadcrumbID {
            
            Task {
                
                await WantToGoArrivalManager
                    .shared
                    .removeGeofence(
                        breadcrumbID:
                            breadcrumbID
                    )
            }
        }
    }
}
