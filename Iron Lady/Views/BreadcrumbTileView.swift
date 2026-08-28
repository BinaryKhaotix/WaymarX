//
//  BreadcrumbTileView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//

import SwiftUI
import CoreLocation

struct BreadcrumbTileView: View {
    let breadcrumb: Breadcrumb

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Tile Content
            HStack(spacing: 10) {
                // Picture
                if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100) // Fixed size for the image
                        //.clipped()
                        .cornerRadius(10) // Rounded corners for the image
                } else {
                    // Placeholder for missing images
                    Color.gray
                        .opacity(0.2)
                        .frame(width: 100, height: 100)
                        .cornerRadius(10)
                }

                // Text Details
                VStack(alignment: .leading, spacing: 5) {
                    Text(breadcrumb.name ?? "Unnamed Pin")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("Group: \(breadcrumb.crmGroup?.groupName ?? "No Group")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Display saved address from Core Data
                    Text(formatAddress(from: breadcrumb))
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Fill available space
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(10)
            .shadow(radius: 5, x: 5, y: 5) // Shadow for the tile

            // Favorite Indicator (Red Heart)
            if breadcrumb.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .padding(8)
                    //.background(Color.white.opacity(0.8))
                    //.clipShape(Circle())
                    //.shadow(radius: 3)
                    .offset(x: -5, y: 5) // Adjust position relative to the tile
            }
        }
    }

    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
        let streetAddress = breadcrumb.streetAddress ?? "No Address"
        let city = breadcrumb.city ?? "No City"
        let state = breadcrumb.state ?? "No State"
        let zipCode = breadcrumb.zipCode ?? "No Zip"

        return "\(streetAddress), \(city), \(state) \(zipCode)"
    }

    private func loadImage(from fileName: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}


//import SwiftUI
//import CoreLocation // Ensure CoreLocation is imported for CLLocation
//
//struct BreadcrumbTileView: View {
//    let breadcrumb: Breadcrumb
//
//    var body: some View {
//        HStack(spacing: 10) {
//            // Picture
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 100, height: 100) // Fixed size for the image
//                    .clipped()
//                    .cornerRadius(10) // Rounded corners for the image
//            } else {
//                // Placeholder for missing images
//                Color.gray
//                    .opacity(0.2)
//                    .frame(width: 100, height: 100)
//                    .cornerRadius(10)
//            }
//
//            // Text Details
//            VStack(alignment: .leading, spacing: 5) {
//                Text(breadcrumb.name ?? "Unnamed")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Blue"))
//                    .lineLimit(1)
//
//                Text("Group: \(breadcrumb.crmGroup?.groupName ?? "No Group")")
//                    .font(.subheadline)
//                    .foregroundColor(Color("Dark Orange"))
//                    .lineLimit(1)
//
//                // Display saved address from Core Data
//                Text(formatAddress(from: breadcrumb))
//                    .font(.footnote)
//                    .foregroundColor(.gray)
//                    .lineLimit(2)
//            }
//            .frame(maxWidth: .infinity, alignment: .leading) // Fill available space
//        }
//        .padding(10)
//        .background(Color.white) // Tile background
//        .cornerRadius(10)
//        .shadow(radius: 5, x: 5, y: 5) // Shadow for the tile
//    }
//
//    private func formatAddress(from breadcrumb: Breadcrumb) -> String {
//        let streetAddress = breadcrumb.streetAddress ?? "No Address"
//        let city = breadcrumb.city ?? "No City"
//        let state = breadcrumb.state ?? "No State"
//        let zipCode = breadcrumb.zipCode ?? "No Zip"
//
//        return "\(streetAddress), \(city), \(state) \(zipCode)"
//    }
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}




//import SwiftUI
//
//struct BreadcrumbTileView: View {
//    let breadcrumb: Breadcrumb
//
//    var body: some View {
//        ZStack {
//            // Picture Background
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFill() // Ensures the image fills the tile
//                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Full tile size
//                    .clipped() // Ensures the image does not overflow
//            } else {
//                // Placeholder for missing images
//                Color.gray
//                    .opacity(0.2)
//            }
//
//            // Breadcrumb Name Text
//            Text(breadcrumb.name ?? "Unnamed")
//                .font(.caption)
//                .foregroundColor(.white) // White text for contrast
//                .shadow(color: .black, radius: 2, x: 1, y: 1) // Text shadow for better readability
//                .multilineTextAlignment(.center)
//                .padding()
//                .bold()
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // Centered text
//                .background(Color.black.opacity(0.4)) // Semi-transparent overlay for text
//        }
//        .cornerRadius(10) // Rounded corners
//        .shadow(radius: 5) // Optional shadow for the entire tile
//    }
//
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}


//import SwiftUI
//
//struct BreadcrumbTileView: View {
//    let breadcrumb: Breadcrumb
//
//    @EnvironmentObject var colorSchemeManager: ColorSchemeManager // Access color scheme
//    @Environment(\.colorScheme) var colorScheme // Detect Light/Dark Mode
//
//    var body: some View {
//        VStack {
//            // Breadcrumb Name
//            Text(breadcrumb.name ?? "Unnamed")
//                .font(.headline)
//                .foregroundColor(foregroundColor) // Dynamic text color
//                .lineLimit(1)
//                .truncationMode(.tail)
//
//            Spacer()
//
//            // Breadcrumb Image or Placeholder
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else {
//                Image(systemName: "photo")
//                    .resizable()
//                    .scaledToFit()
//                    .foregroundColor(placeholderColor) // Dynamic placeholder color
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
//
//            Spacer()
//
//            // Group Name
//            Text(breadcrumb.crmGroup?.groupName ?? "No Group")
//                .font(.caption)
//                .foregroundColor(secondaryForegroundColor) // Dynamic secondary text color
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 15)
//                .fill(backgroundColor) // Fill with desired background color
//        )
//    }
//
//    // MARK: - Dynamic Colors
//    private var foregroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.light : colorSchemeManager.currentScheme.dark
//    }
//
//    private var secondaryForegroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundDark.opacity(0.7) : colorSchemeManager.currentScheme.backgroundLight.opacity(0.7)
//    }
//
//    private var backgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    private var placeholderColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.dark.opacity(0.8) : colorSchemeManager.currentScheme.light.opacity(0.8)
//    }
//
//    // MARK: - Helper Functions
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = getDocumentsDirectory().appendingPathComponent(fileName)
//        return UIImage(contentsOfFile: url.path)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
