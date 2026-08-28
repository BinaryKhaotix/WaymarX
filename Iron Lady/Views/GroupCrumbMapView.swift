//
//  GroupCrumbMapView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/14/25.
//

import SwiftUI
import MapKit

struct GroupCrumbMapView: View {
    let breadcrumbs: [Breadcrumb]

    @State private var region: MKCoordinateRegion
    @EnvironmentObject var navigationModel: NavigationModel
    @FetchRequest(
        entity: CrumbUser.entity(),
        sortDescriptors: []
    ) private var users: FetchedResults<CrumbUser> // Fetch user data for home location

    private let groupName: String // Group name derived from breadcrumbs

    init(breadcrumbs: [Breadcrumb]) {
        self.breadcrumbs = breadcrumbs
        self.groupName = breadcrumbs.first?.crmGroup?.groupName ?? "Unknown Group"

        // Initialize map region based on the first breadcrumb
        if let firstBreadcrumb = breadcrumbs.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: firstBreadcrumb.latitude, longitude: firstBreadcrumb.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: buildAnnotations()) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                Button(action: {
                    handleAnnotationTap(annotation)
                }) {
                    VStack {
                        Image(systemName: annotation.isHome ? "house.fill" : "mappin.circle.fill")
                            .foregroundColor(annotation.isHome ? .green : .red)
                            .font(.title)
                        Text(annotation.title)
                            .font(.caption)
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(5)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle("Group: \(groupName)")
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

    // Build annotations for breadcrumbs and home location
    private func buildAnnotations() -> [GroupCrumbAnnotation] {
        var annotations = breadcrumbs.map {
            GroupCrumbAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                title: $0.name ?? "Unnamed",
                isHome: false,
                breadcrumb: $0
            )
        }

        // Add home location from Core Data if available
        if let user = users.first, user.homeLatitude != 0.0, user.homeLongitude != 0.0 {
            annotations.append(GroupCrumbAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: user.homeLatitude, longitude: user.homeLongitude),
                title: "Home",
                isHome: true,
                breadcrumb: nil
            ))
        }

        return annotations
    }

    // Handle annotation taps
    private func handleAnnotationTap(_ annotation: GroupCrumbAnnotation) {
        if let breadcrumb = annotation.breadcrumb {
            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
        }
    }
}

// Annotation struct to differentiate between breadcrumbs and home location
struct GroupCrumbAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isHome: Bool
    let breadcrumb: Breadcrumb?
}


//import SwiftUI
//import MapKit
//
//struct GroupCrumbMapView: View {
//    let breadcrumbs: [Breadcrumb]
//
//    @State private var region: MKCoordinateRegion
//    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
//    @FetchRequest(
//        entity: CrumbUser.entity(),
//        sortDescriptors: []
//    ) private var users: FetchedResults<CrumbUser> // Fetch user data for home location
//
//    private var crmGroup?.groupName: String // Dynamically derived group name
//
//    init(breadcrumbs: [Breadcrumb]) {
//        self.breadcrumbs = breadcrumbs
//        self.crmGroup?.groupName = breadcrumbs.first?.crmGroup?.groupName ?? "Unknown Group"
//
//        // Determine the initial map region based on the breadcrumbs
//        if let firstBreadcrumb = breadcrumbs.first {
//            _region = State(initialValue: MKCoordinateRegion(
//                center: CLLocationCoordinate2D(latitude: firstBreadcrumb.latitude, longitude: firstBreadcrumb.longitude),
//                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//            ))
//        } else {
//            _region = State(initialValue: MKCoordinateRegion(
//                center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
//                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//            ))
//        }
//    }
//
//    var body: some View {
//        Map(coordinateRegion: $region, annotationItems: buildAnnotations()) { annotation in
//            MapAnnotation(coordinate: annotation.coordinate) {
//                Button(action: {
//                    handleAnnotationTap(annotation)
//                }) {
//                    VStack {
//                        Image(systemName: annotation.isHome ? "house.fill" : "mappin.circle.fill")
//                            .foregroundColor(annotation.isHome ? .green : .red)
//                            .font(.title)
//                        Text(annotation.title)
//                            .font(.caption)
//                            .padding(4)
//                            .background(Color.white.opacity(0.8))
//                            .cornerRadius(5)
//                    }
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//        .navigationTitle("Group: \(crmGroup?.groupName)")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
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
//        }
//    }
//
//    // Build annotations for breadcrumbs and home location
//    private func buildAnnotations() -> [GroupCrumbAnnotation] {
//        var annotations = breadcrumbs.map {
//            GroupCrumbAnnotation(
//                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
//                title: $0.name ?? "Unnamed",
//                isHome: false,
//                breadcrumb: $0
//            )
//        }
//
//        // Add home location from Core Data if available
//        if let user = users.first {
//            let homeLatitude = user.homeLatitude
//            let homeLongitude = user.homeLongitude
//            if homeLatitude != 0.0 && homeLongitude != 0.0 {
//                annotations.append(GroupCrumbAnnotation(
//                    coordinate: CLLocationCoordinate2D(latitude: homeLatitude, longitude: homeLongitude),
//                    title: "Home",
//                    isHome: true,
//                    breadcrumb: nil
//                ))
//            }
//        }
//
//        return annotations
//    }
//
//    // Handle annotation taps
//    private func handleAnnotationTap(_ annotation: GroupCrumbAnnotation) {
//        if let breadcrumb = annotation.breadcrumb {
//            navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//        }
//    }
//}
//
//// Annotation struct to differentiate between breadcrumbs and home location
//struct GroupCrumbAnnotation: Identifiable {
//    let id = UUID()
//    let coordinate: CLLocationCoordinate2D
//    let title: String
//    let isHome: Bool
//    let breadcrumb: Breadcrumb?
//}




//import SwiftUI
//import MapKit
//
//struct GroupCrumbMapView: View {
//    let breadcrumbs: [Breadcrumb]
//
//    @State private var region: MKCoordinateRegion
//    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
//    private var crmGroup?.groupName: String // Dynamically derived group name
//
//    init(breadcrumbs: [Breadcrumb]) {
//        self.breadcrumbs = breadcrumbs
//        self.crmGroup?.groupName = breadcrumbs.first?.crmGroup?.groupName ?? "Unknown Group" // Derive group name
//
//        // Determine the initial map region based on the breadcrumbs
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
//            MapAnnotation(
//                coordinate: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude)
//            ) {
//                Button(action: {
//                    // Navigate to BreadcrumbDetailView using NavigationModel
//                    navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                }) {
//                    VStack {
//                        Image(systemName: "mappin.circle.fill")
//                            .foregroundColor(.red)
//                            .font(.title)
//                        Text(breadcrumb.name ?? "Unnamed")
//                            .font(.caption)
//                            .padding(4)
//                            .background(Color.white.opacity(0.8))
//                            .cornerRadius(5)
//                    }
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//        .navigationTitle("Group: \(crmGroup?.groupName)") // Use the derived group name
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}

//import SwiftUI
//import MapKit
//
//struct GroupCrumbMapView: View {
//    let breadcrumbs: [Breadcrumb]
//    let crmGroup?.groupName: String
//
//    @State private var region: MKCoordinateRegion
//
//    init(breadcrumbs: [Breadcrumb]) {
//        self.breadcrumbs = breadcrumbs
//        self.crmGroup?.groupName = breadcrumbs.first?.crmGroup?.groupName ?? "Unknown Group"
//
//        // Determine the initial map region based on the breadcrumbs
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
//            MapAnnotation(
//                coordinate: CLLocationCoordinate2D(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude)
//            ) {
//                VStack {
//                    Image(systemName: "mappin.circle.fill")
//                        .foregroundColor(.red)
//                        .font(.title)
//                    Text(breadcrumb.name ?? "Unnamed")
//                        .font(.caption)
//                        .padding(4)
//                        .background(Color.white.opacity(0.8))
//                        .cornerRadius(5)
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//        .navigationTitle("Group: \(crmGroup?.groupName)")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}







