//
//  BreadcrumbMapView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//

import SwiftUI
import MapKit

struct BreadcrumbMapView: View {
    let breadcrumb: Breadcrumb // Single breadcrumb to display on the map

    @State private var region: MKCoordinateRegion
    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
    @FetchRequest(entity: CrumbUser.entity(), sortDescriptors: []) private var users: FetchedResults<CrumbUser> // Fetch the user

    init(breadcrumb: Breadcrumb) {
        self.breadcrumb = breadcrumb

        // Set the initial map region based on the breadcrumb
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: createAnnotations()) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                if annotation.type == .breadcrumb {
                    Button(action: {
                        // Navigate back to BreadcrumbDetailView
                        navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
                    }) {
                        VStack {
                            Text(breadcrumb.name ?? "Unnamed")
                                .font(.caption)
                                .padding(5)
                                .background(Color.white.opacity(0.8))
                                .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.6))
                                .bold()
                                .cornerRadius(5)

                            Image(systemName: "mappin.and.ellipse")
                                .renderingMode(.original)
                                .font(.title)
                                .tint(Color(red: 0.85, green: 0.1, blue: 0.1))
                        }
                    }
                } else if annotation.type == .home {
                    VStack {
                        Text("Home")
                            .font(.caption)
                            .padding(5)
                            .background(Color.white.opacity(0.8))
                            .foregroundColor(.green)
                            .bold()
                            .cornerRadius(5)

                        Image(systemName: "house.circle.fill")
                            .renderingMode(.original)
                            .font(.title)
                            .tint(.green)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle("Location: \(breadcrumb.name ?? "Unnamed Pin")")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
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
        }

        
    }

    // Helper function to create annotations
    private func createAnnotations() -> [MapAnnotationItem] {
        var annotations = [MapAnnotationItem]()

        // Add the breadcrumb as an annotation
        annotations.append(MapAnnotationItem(
            coordinate: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude),
            type: .breadcrumb
        ))

        // Add the user's home location as an annotation if available
        if let user = users.first, user.homeLatitude != 0.0, user.homeLongitude != 0.0 {
            annotations.append(MapAnnotationItem(
                coordinate: CLLocationCoordinate2D(latitude: user.homeLatitude, longitude: user.homeLongitude),
                type: .home
            ))
        }

        return annotations
    }
}

// Enum to differentiate annotation types
enum AnnotationType {
    case breadcrumb
    case home
}

// Helper struct to make annotations identifiable
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
}


//import SwiftUI
//import MapKit
//
//struct BreadcrumbMapView: View {
//    let breadcrumb: Breadcrumb // Single breadcrumb to display on the map
//
//    @State private var region: MKCoordinateRegion
//    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
//
//    init(breadcrumb: Breadcrumb) {
//        self.breadcrumb = breadcrumb
//
//        // Set the initial map region based on the breadcrumb
//        self._region = State(initialValue: MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude),
//            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//        ))
//    }
//
//    var body: some View {
//        Map(coordinateRegion: $region, annotationItems: [breadcrumb].map { IdentifiableBreadcrumb(breadcrumb: $0) }) { identifiableBreadcrumb in
//            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: identifiableBreadcrumb.breadcrumb.latitude, longitude: identifiableBreadcrumb.breadcrumb.longitude)) {
//                Button(action: {
//                    // Navigate back to BreadcrumbDetailView if needed
//                    navigationModel.path.append(.breadcrumbDetail(breadcrumb: identifiableBreadcrumb.breadcrumb))
//                }) {
//                    VStack {
//                        Text(identifiableBreadcrumb.breadcrumb.name ?? "Unnamed")
//                            .font(.caption)
//                            .padding(5)
//                            .background(Color.white.opacity(0.8))
//                            .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.6))
//                            .bold()
//                            .cornerRadius(5)
//
//                        Image(systemName: "mappin.and.ellipse")
//                            .renderingMode(.original)
//                            .font(.title)
//                            .tint(Color(red: 0.85, green: 0.1, blue: 0.1))
//                    }
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//        .navigationTitle("Location: \(breadcrumb.name ?? "Unnamed")")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
//
//// Helper struct to make Breadcrumb identifiable
//struct IdentifiableBreadcrumb: Identifiable {
//    let id = UUID()
//    let breadcrumb: Breadcrumb
//}


//import SwiftUI
//import MapKit
//
//struct BreadcrumbMapView: View {
//    let breadcrumb: Breadcrumb // Single breadcrumb to display on the map
//
//    @State private var region: MKCoordinateRegion
//    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
//
//    init(breadcrumb: Breadcrumb) {
//        self.breadcrumb = breadcrumb
//
//        // Set the initial map region based on the breadcrumb
//        self._region = State(initialValue: MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude),
//            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//        ))
//    }
//
//    var body: some View {
//        Map(coordinateRegion: $region, annotationItems: [breadcrumb]) { breadcrumb in
//            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude)) {
//                VStack {
//                    Text(breadcrumb.name ?? "Unnamed")
//                        .font(.caption)
//                        .padding(5)
//                        .background(Color.white.opacity(0.8))
//                        .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.6))
//                        .bold()
//                        .cornerRadius(5)
//
//                    Image(systemName: "mappin.and.ellipse")
//                        .renderingMode(.original)
//                        .font(.title)
//                        .tint(Color(red: 0.85, green: 0.1, blue: 0.1))
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//        .navigationTitle("Location: \(breadcrumb.name ?? "Unnamed")")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}


//import SwiftUI
//import MapKit
//
//struct BreadcrumbMapView: View {
//    let breadcrumbs: [Breadcrumb]
//
//    @State private var region: MKCoordinateRegion
//    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
//
//    init(breadcrumbs: [Breadcrumb]) {
//        self.breadcrumbs = breadcrumbs
//
//        // Determine the initial map region based on the first breadcrumb
//        if let firstBreadcrumb = breadcrumbs.first {
//            _region = State(initialValue: MKCoordinateRegion(
//                center: CLLocationCoordinate2D(latitude: firstBreadcrumb.latitude, longitude: firstBreadcrumb.longitude),
//                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//            ))
//        } else {
//            // Default region if no breadcrumbs are available
//            _region = State(initialValue: MKCoordinateRegion(
//                center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
//                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//            ))
//        }
//    }
//
//    var body: some View {
//        Map(coordinateRegion: $region, annotationItems: breadcrumbs) { breadcrumb in
//            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude)) {
//                Button(action: {
//                    // Use NavigationModel to navigate to BreadcrumbDetailView
//                    navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                }) {
//                    VStack {
//                        Text(breadcrumb.name ?? "Unnamed")
//                            .font(.caption)
//                            .padding(5)
//                            .background(Color.white.opacity(0.8))
//                            .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.6))
//                            .bold()
//                            .cornerRadius(5)
//
//                        Image(systemName: "mappin.and.ellipse")
//                            .renderingMode(.original)
//                            .font(.title)
//                            .tint(Color(red: 0.85, green: 0.1, blue: 0.1))
//                    }
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//        .navigationTitle("Location: \(breadcrumb.name)")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}


//import SwiftUI
//import MapKit
//
//struct BreadcrumbMapView: View {
//    let latitude: Double
//    let longitude: Double
//    let name: String
//
//    @State private var region: MKCoordinateRegion
//
//    init(latitude: Double, longitude: Double, name: String) {
//        self.latitude = latitude
//        self.longitude = longitude
//        self.name = name
//        self._region = State(initialValue: MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
//            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//        ))
//    }
//
//    var body: some View {
//        VStack {
//            Map(coordinateRegion: $region, annotationItems: [MapPin(latitude: latitude, longitude: longitude, name: name)]) { pin in
//                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
//                    VStack {
//                        Text(pin.name)
//                            .font(.caption)
//                            .padding(5)
//                            .background(Color.white.opacity(0.8))
//                            .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.6))
//                            .bold()
//                            .cornerRadius(5)
//
//                        Image(systemName: "mappin.and.ellipse") //mappin.circle.fill")
//                            .renderingMode(.original)
//                            .font(.title)
//                            .tint(Color(red: 0.85, green: 0.1, blue: 0.1))
//                            //.symbolEffect(.bounce.up.wholeSymbol, options: .nonRepeating)
//                    }
//                }
//            }
//            .edgesIgnoringSafeArea(.all)
//        }
//        .navigationTitle("Location: \(name)")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
//
//struct MapPin: Identifiable {
//    let id = UUID()
//    let latitude: Double
//    let longitude: Double
//    let name: String
//}
