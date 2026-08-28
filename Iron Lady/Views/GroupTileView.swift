//
//  GroupTileView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/12/24.
//

import SwiftUI

struct GroupTileView: View {
    let group: CrmGroup

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Group Image
            Group {
                if let image = randomImage(from: group.breadcrumbsArray) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // SF Symbol Placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "folder.fill") // Change this symbol as needed
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    }
                }
            }

            // Group Details
            VStack(alignment: .leading, spacing: 5) {
                Text(group.groupName ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primary)

                if let description = group.groupDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let dateCreated = group.dateCreated {
                    Text("Created: \(formattedDate(dateCreated))")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer()
        }
    }

    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
           let fileName = randomBreadcrumb.photoURL {
            return loadImage(from: fileName)
        }
        return nil
    }

    private func loadImage(from fileName: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
        return url.flatMap { UIImage(contentsOfFile: $0.path) }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}


//import SwiftUI
//
//struct GroupTileView: View {
//    let group: CrmGroup
//
//    var body: some View {
//        HStack(alignment: .top, spacing: 10) {
//            // Group Image
//            Group {
//                if let image = randomImage(from: group.breadcrumbsArray) {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 60, height: 60)
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                } else {
//                    Image("defaultGroupImage")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 60, height: 60)
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                }
//            }
//
//            // Group Details
//            VStack(alignment: .leading, spacing: 5) {
//                Text(group.crmGroup?.groupName ?? "Unknown")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//
//                if let description = group.groupDescription {
//                    Text(description)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .lineLimit(2)
//                }
//
//                if let dateCreated = group.dateCreated {
//                    Text("Established: \(formattedDate(dateCreated))")
//                        .font(.footnote)
//                        .foregroundColor(.gray)
//                }
//            }
//
//            Spacer()
//        }
//    }
//
//    // MARK: - Select a Random Image from Breadcrumbs with Images
//    private func randomImage(from breadcrumbs: [Breadcrumb]) -> UIImage? {
//        // Filter breadcrumbs to only include those with valid photoURLs
//        let photoBreadcrumbs = breadcrumbs.filter { $0.photoURL != nil }
//        if let randomBreadcrumb = photoBreadcrumbs.randomElement(),
//           let fileName = randomBreadcrumb.photoURL {
//            return loadImage(from: fileName)
//        }
//        return nil
//    }
//
//    // MARK: - Load Image from File
//    private func loadImage(from fileName: String) -> UIImage? {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
//        return url.flatMap { UIImage(contentsOfFile: $0.path) }
//    }
//
//    // MARK: - Format Date for Display
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        return formatter.string(from: date)
//    }
//}


//import SwiftUI
//
//struct GroupTileView: View {
//    let crmGroup?.groupName: String
//    let image: UIImage?
//
//    var body: some View {
//        ZStack {
//            // Background image
//            if let image = image {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 100, height: 100)
//                    .clipped()
//                    .cornerRadius(10)
//            } else {
//                Rectangle()
//                    .fill(Color.gray.opacity(0.3))
//                    .frame(width: 100, height: 100)
//                    .cornerRadius(10)
//                    .overlay(Text("No Image").foregroundColor(.gray))
//            }
//
//            // Group name overlay
//            Text(crmGroup?.groupName)
//                .font(.caption)
//                .foregroundColor(.white)
//                .shadow(radius: 5)
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 10)
//                        .fill(Color.clear)
//                        .padding(.horizontal, 10)
//                )
//        }
//        .frame(maxWidth: .infinity)
//        .cornerRadius(10)
//        .shadow(radius: 5, x: 5, y: 5)
//    }
//}



//import SwiftUI
//
//struct GroupTileView: View {
//
//    let crmGroup?.groupName: String
//
//    var body: some View {
//        VStack {
//            // Group Name
//            Text(crmGroup?.groupName)
//                .font(.caption)
//                .multilineTextAlignment(.center)
//                .lineLimit(nil)
//                .foregroundColor(Color("Dark Blue"))
//                .bold()
//                .padding(0.1)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(
//            RoundedRectangle(cornerRadius: 25)
//                .fill(.white)
//        )
//        .cornerRadius(10)
//        .shadow(radius: 5)
//    }
//
//}



//import SwiftUI
//
//struct GroupTileView: View {
//    @EnvironmentObject var colorSchemeManager: ColorSchemeManager // Access color scheme
//    @Environment(\.colorScheme) var colorScheme // Detect Light/Dark mode
//
//    let crmGroup?.groupName: String
//
//    var body: some View {
//        VStack {
//            // Group Name
//            Text(crmGroup?.groupName)
//                .font(.headline)
//                .lineLimit(1)
//                .truncationMode(.tail)
//                .foregroundColor(foregroundColor) // Dynamic text color
//                .padding(.top)
//
//            Spacer()
//
//            // Folder Icon
//            Image(systemName: "folder")
//                .resizable()
//                .scaledToFit()
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .foregroundColor(iconColor) // Dynamic icon color
//
//            Spacer()
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 25)
//                .fill(backgroundColor) // Fill with desired background color
//        )
//        .cornerRadius(10) // Rounded corners
//    }
//
//    // MARK: - Dynamic Colors
//    private var foregroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.light : colorSchemeManager.currentScheme.dark
//    }
//
//    private var backgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark
//    }
//
//    private var iconColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.dark.opacity(0.8) : colorSchemeManager.currentScheme.light.opacity(0.8)
//    }
//}
//
//
