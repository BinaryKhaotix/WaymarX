//
//  WantToGoMapView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/28/26.
//

import SwiftUI
import MapKit
import CoreData
import CoreLocation

struct WantToGoMapView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationModel: NavigationModel
    
    // MARK: - Search
    
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    
    // MARK: - Selected Destination
    
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedPlaceName: String?
    @State private var selectedCity: String?
    @State private var selectedState: String?
    
    @State private var note: String = ""
    
    // MARK: - Save
    
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var showingSavedAlert: Bool = false
    
    // MARK: - Map
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 20,
            longitude: 0
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 80,
            longitudeDelta: 80
        )
    )
    
    var body: some View {
        
        ZStack {
            
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                searchSection
                
                if !searchResults.isEmpty {
                    searchResultsSection
                }
                
                mapSection
                
                if selectedCoordinate != nil {
                    destinationCard
                }
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
            "Added to Want to Go",
            isPresented: $showingSavedAlert
        ) {
            Button("OK") {
                navigationModel.pop()
            }
        } message: {
            Text(
                "\(selectedPlaceName ?? "Destination") was saved to your Want to Go list."
            )
        }
        
        .alert(
            "Error",
            isPresented: Binding(
                get: {
                    searchError != nil || saveError != nil
                },
                set: { _ in
                    searchError = nil
                    saveError = nil
                }
            )
        ) {
            Button("OK") {
                searchError = nil
                saveError = nil
            }
        } message: {
            Text(
                saveError
                ?? searchError
                ?? "An unknown error occurred."
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
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            HStack(spacing: 10) {
                
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField(
                    "Search for a place...",
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }
                
                if !searchText.isEmpty {
                    
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(
                            systemName: "xmark.circle.fill"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    performSearch()
                } label: {
                    
                    if isSearching {
                        ProgressView()
                    } else {
                        Image(
                            systemName: "arrow.right.circle.fill"
                        )
                        .font(.title2)
                    }
                }
                .disabled(
                    searchText
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty
                    || isSearching
                )
            }
            .padding(12)
            .background(
                Color(.secondarySystemBackground)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            
            Text(
                "Search for somewhere you've always wanted to go, or explore the map and long-press a location."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Search Results
    
    private var searchResultsSection: some View {
        
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            
            HStack(spacing: 10) {
                
                ForEach(
                    searchResults.indices,
                    id: \.self
                ) { index in
                    
                    let item = searchResults[index]
                    
                    Button {
                        
                        selectSearchResult(item)
                        
                    } label: {
                        
                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            
                            Text(
                                item.name
                                ?? "Unknown Place"
                            )
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            
                            if let subtitle =
                                item.placemark.title {
                                
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                    .lineLimit(2)
                            }
                        }
                        .padding(12)
                        .frame(
                            width: 230,
                            alignment: .leading
                        )
                        .background(
                            Color(
                                .secondarySystemBackground
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Map
    
    private var mapSection: some View {
        
        WantToGoMapRepresentable(
            region: $region,
            selectedCoordinate: $selectedCoordinate,
            selectedPlaceName: $selectedPlaceName,
            selectedCity: $selectedCity,
            selectedState: $selectedState
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay {
            
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                Color.secondary.opacity(0.25),
                lineWidth: 1
            )
        }
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Destination Card
    
    private var destinationCard: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(alignment: .top) {
                
                Image(
                    systemName: "mappin.and.ellipse"
                )
                .font(.title2)
                .foregroundStyle(.red)
                
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    
                    Text(
                        selectedPlaceName
                        ?? "Selected Destination"
                    )
                    .font(.headline)
                    
                    if !locationSubtitle.isEmpty {
                        
                        Text(locationSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                
                Text("Why do you want to go?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                TextField(
                    "Optional note...",
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .padding(10)
                .background(
                    Color(.tertiarySystemBackground)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
            }
            
            Button {
                
                saveDestination()
                
            } label: {
                
                HStack {
                    
                    Spacer()
                    
                    if isSaving {
                        
                        ProgressView()
                            .tint(.white)
                        
                    } else {
                        
                        Image(
                            systemName: "bookmark.fill"
                        )
                        
                        Text("Add to Want to Go")
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding()
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
            .disabled(
                selectedCoordinate == nil
                || isSaving
            )
        }
        .padding()
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .padding()
    }
    
    // MARK: - Subtitle
    
    private var locationSubtitle: String {
        
        var parts: [String] = []
        
        if let city = selectedCity,
           !city.isEmpty {
            
            parts.append(city)
        }
        
        if let state = selectedState,
           !state.isEmpty {
            
            parts.append(state)
        }
        
        return parts.joined(
            separator: ", "
        )
    }
    
    // MARK: - Search
    
    private func performSearch() {
        
        searchError = nil
        
        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        
        guard !query.isEmpty else {
            return
        }
        
        isSearching = true
        searchResults = []
        
        let request = MKLocalSearch.Request()
        
        request.naturalLanguageQuery = query
        
        MKLocalSearch(
            request: request
        )
        .start { response, error in
            
            DispatchQueue.main.async {
                
                isSearching = false
                
                if let error = error {
                    
                    searchError =
                    error.localizedDescription
                    
                    return
                }
                
                guard let items =
                        response?.mapItems,
                      !items.isEmpty
                else {
                    
                    searchError =
                    "No places were found."
                    
                    return
                }
                
                searchResults = items
                
                // Move the map to the first result,
                // but do not select it until the
                // user taps a result.
                focusMap(
                    on: items[0]
                )
            }
        }
    }
    
    // MARK: - Select Search Result
    
    private func selectSearchResult(
        _ item: MKMapItem
    ) {
        
        let coordinate =
        item.placemark.coordinate
        
        selectedCoordinate = coordinate
        
        selectedPlaceName =
        item.name ?? "Destination"
        
        selectedCity =
        item.placemark.locality
        
        selectedState =
        item.placemark.administrativeArea
        
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 0.03,
                longitudeDelta: 0.03
            )
        )
        
        searchResults = []
    }
    
    // MARK: - Focus Map
    
    private func focusMap(
        on item: MKMapItem
    ) {
        
        region = MKCoordinateRegion(
            center: item.placemark.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 2,
                longitudeDelta: 2
            )
        )
    }
    
    // MARK: - Save
    
    private func saveDestination() {
        
        guard let coordinate =
                selectedCoordinate
        else {
            return
        }
        
        saveError = nil
        isSaving = true
        
        Task {
            
            let imageFileName =
            await WantToGoImageManager.shared
                .createDestinationImage(
                    coordinate: coordinate
                )
            
            await MainActor.run {
                
                let breadcrumb =
                Breadcrumb(
                    context: viewContext
                )
                
                breadcrumb.id = UUID()
                
                breadcrumb.name =
                selectedPlaceName
                ?? "Want to Go"
                
                breadcrumb.latitude =
                coordinate.latitude
                
                breadcrumb.longitude =
                coordinate.longitude
                
                breadcrumb.city =
                selectedCity
                
                breadcrumb.state =
                selectedState
                
                breadcrumb.note =
                note.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                
                breadcrumb.isFavorite = false
                
                // MARK: Want to Go
                breadcrumb.isWantToGo = true
                
                breadcrumb.wantToGoDate =
                Date()
                
                breadcrumb.visitedDate =
                nil
                
                breadcrumb.arrivalRadius =
                NSNumber(
                    value: 300.0
                )
                
                // Save Look Around / map snapshot filename
                breadcrumb.photoURL =
                imageFileName
                
                do {

                    try viewContext.save()

                    Task {
                        await WantToGoArrivalManager.shared
                            .addGeofence(
                                for: breadcrumb
                            )
                    }

                    isSaving = false
                    showingSavedAlert = true

                } catch {
                    
                    viewContext.rollback()
                    
                    isSaving = false
                    saveError =
                    error.localizedDescription
                }
            }
        }
    }
}

// MARK: - UIKit Map Wrapper

private struct WantToGoMapRepresentable:
    UIViewRepresentable {

    @Binding var region:
        MKCoordinateRegion

    @Binding var selectedCoordinate:
        CLLocationCoordinate2D?

    @Binding var selectedPlaceName:
        String?

    @Binding var selectedCity:
        String?

    @Binding var selectedState:
        String?

    func makeUIView(
        context: Context
    ) -> MKMapView {

        let map =
            MKMapView(
                frame: .zero
            )

        map.delegate =
            context.coordinator

        map.showsCompass = true
        map.showsScale = true
        map.isRotateEnabled = true

        map.setRegion(
            region,
            animated: false
        )

        let longPress =
            UILongPressGestureRecognizer(
                target:
                    context.coordinator,
                action:
                    #selector(
                        Coordinator.handleLongPress(_:)
                    )
            )

        longPress.minimumPressDuration =
            0.45

        longPress.cancelsTouchesInView =
            false

        map.addGestureRecognizer(
            longPress
        )

        return map
    }

    func updateUIView(
        _ map: MKMapView,
        context: Context
    ) {

        if !context.coordinator
            .isUserInteracting {

            map.setRegion(
                region,
                animated: true
            )
        }

        map.removeAnnotations(
            map.annotations
        )

        if let coordinate =
            selectedCoordinate {

            let annotation =
                MKPointAnnotation()

            annotation.coordinate =
                coordinate

            annotation.title =
                selectedPlaceName
                ?? "Want to Go"

            map.addAnnotation(
                annotation
            )
        }
    }

    func makeCoordinator()
        -> Coordinator {

        Coordinator(self)
    }


    // MARK: - Coordinator

    final class Coordinator:
        NSObject,
        MKMapViewDelegate {

        var parent:
            WantToGoMapRepresentable

        var isUserInteracting =
            false

        init(
            _ parent:
                WantToGoMapRepresentable
        ) {

            self.parent =
                parent
        }

        // MARK: Long Press

        @objc
        func handleLongPress(
            _ gesture:
                UILongPressGestureRecognizer
        ) {

            guard
                gesture.state == .began,
                let map =
                    gesture.view
                    as? MKMapView
            else {
                return
            }

            let point =
                gesture.location(
                    in: map
                )

            let coordinate =
                map.convert(
                    point,
                    toCoordinateFrom: map
                )

            parent.selectedCoordinate =
                coordinate

            parent.selectedPlaceName =
                "Selected Location"

            parent.selectedCity =
                nil

            parent.selectedState =
                nil

            reverseGeocode(
                coordinate
            )
        }

        // MARK: Reverse Geocode

        private func reverseGeocode(
            _ coordinate:
                CLLocationCoordinate2D
        ) {

            let location =
                CLLocation(
                    latitude:
                        coordinate.latitude,
                    longitude:
                        coordinate.longitude
                )

            CLGeocoder()
                .reverseGeocodeLocation(
                    location
                ) { placemarks, _ in

                    guard let placemark =
                            placemarks?.first
                    else {
                        return
                    }

                    DispatchQueue.main.async {

                        self.parent
                            .selectedPlaceName =
                            placemark.name
                            ?? placemark.locality
                            ?? "Selected Location"

                        self.parent
                            .selectedCity =
                            placemark.locality

                        self.parent
                            .selectedState =
                            placemark
                                .administrativeArea
                    }
                }
        }

        // MARK: Map Interaction

        func mapView(
            _ mapView: MKMapView,
            regionWillChangeAnimated
                animated: Bool
        ) {

            isUserInteracting = true
        }

        func mapView(
            _ mapView: MKMapView,
            regionDidChangeAnimated
                animated: Bool
        ) {

            isUserInteracting = false

            parent.region =
                mapView.region
        }
    }
}
