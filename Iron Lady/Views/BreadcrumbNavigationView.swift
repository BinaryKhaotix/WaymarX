//
//  NavigationView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/15/25.
//

import SwiftUI
import MapKit

struct BreadcrumbNavigationView: View {
    let breadcrumb: Breadcrumb
    @State private var selectedMap: String = "Apple Maps"
    @EnvironmentObject var navigationModel: NavigationModel


    var body: some View {
        VStack(spacing: 20) {
            Text("Navigate to: \(breadcrumb.name ?? "Unknown Location")")
                .font(.title2)
                .bold()
                .padding()

            Picker("Select Map", selection: $selectedMap) {
                Text("Apple Maps").tag("Apple Maps")
                Text("Google Maps").tag("Google Maps")
                Text("Waze").tag("Waze")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Button("Navigate") {
                navigateToLocation()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            Spacer()
        }
        .padding()
        .navigationTitle("Navigate")
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

    private func navigateToLocation() {
        let latitude = breadcrumb.latitude
        let longitude = breadcrumb.longitude
        let coordinateString = "\(latitude),\(longitude)"

        switch selectedMap {
        case "Google Maps":
            let url = URL(string: "comgooglemaps://?daddr=\(coordinateString)&directionsmode=driving")!
            UIApplication.shared.open(url)

        case "Waze":
            let url = URL(string: "waze://?ll=\(coordinateString)&navigate=yes")!
            UIApplication.shared.open(url)

        default: // Apple Maps
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        }
    }
}
