//
//  TileContainerView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/12/24.
//

import SwiftUI

struct TileContainerView<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title Section
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal)
                .foregroundColor(.black)

            // Horizontal Scrolling Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: 100, height: 100) // Fixed square tiles
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
                .padding(.horizontal, 20) // Padding around the horizontal scroll
            }
            .frame(height: 100) // Fixed height to accommodate one row of tiles and spacing
        }
        .padding(.vertical, 10) // Padding around the container
    }
}


//import SwiftUI
//
//struct TileContainerView<Item: Identifiable, Content: View>: View {
//    let title: String
//    let items: [Item]
//    let content: (Item) -> Content
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            // Title Section
//            Text(title)
//                .font(.title2)
//                .bold()
//                .padding(.horizontal)
//                .foregroundColor(Color("Dark Orange"))
//
//            // Dynamic Grid Layout
//            GeometryReader { geometry in
//                let tileSize = (geometry.size.width - 60) / 3 // Adjust for padding (20 horizontal padding on both sides)
//                LazyVGrid(
//                    columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 10), count: 3),
//                    spacing: 10
//                ) {
//                    ForEach(items) { item in
//                        content(item)
//                            .frame(width: tileSize, height: tileSize) // Square tiles
//                            .background(Color.gray.opacity(0.2))
//                            .cornerRadius(10)
//                            .shadow(radius: 5)
//                    }
//                }
//                .padding(.horizontal, 20) // Padding inside the container
//            }
//            .frame(minHeight: calculateHeight(for: items.count)) // Adjust height dynamically
//        }
//        .padding(.vertical, 10) // Padding around the container
//    }
//
//    // Calculate height for rows of three
//    private func calculateHeight(for itemCount: Int) -> CGFloat {
//        let rows = ceil(Double(itemCount) / 3.0)
//        return CGFloat(rows * 120 + (rows - 1) * 10) // Tile height 120, spacing 10
//    }
//}



//import SwiftUI
//
//struct TileContainerView<Item, Content>: View where Item: Identifiable, Content: View {
//    @EnvironmentObject var colorSchemeManager: ColorSchemeManager // Access color scheme
//    @Environment(\.colorScheme) var colorScheme // Detect Light/Dark mode
//
//    let title: String
//    let items: [Item]
//    let content: (Item) -> Content
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 2) {
//            // Section Title
//            Text(title)
//                .font(.title2)
//                .bold()
//                .foregroundColor(.white) //titleForegroundColor) // Dynamic title color
//                .padding(.horizontal)
//
//            GeometryReader { geometry in
//                let tileSize = geometry.size.width / 3 - 15 // Adjust for spacing
//
//                LazyVGrid(columns: [GridItem(.fixed(tileSize)), GridItem(.fixed(tileSize))], spacing: 4) {
//                    ForEach(items) { item in
//                        content(item)
//                            .frame(width: tileSize, height: tileSize)
//                    }
//                }
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 15)
//                        .fill(tileBackgroundColor) // Fill with desired background color
//                )
//
//            }
//            .padding()
//            .frame(height: 200) // Set height for predictable layout
//            .background(tileBackgroundColor)
////                RoundedRectangle(cornerRadius: 15)
////                    .fill(tileBackgroundColor) // Fill with desired background color
////            )
//            .cornerRadius(10) // Rounded corners for section
//        }
//        .padding(.vertical, 5) // Adjust vertical spacing between sections
//        .padding(.horizontal, 1)
//        .background(
//            RoundedRectangle(cornerRadius: 15)
//                .fill(tileBackgroundColor) // Fill with desired background color
//        )
//        //.shadow(radius: 5) // Optional: Add a shadow for a nice effect
//    }
//
//    // MARK: - Dynamic Colors
//    private var foregroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.light : colorSchemeManager.currentScheme.dark
//    }
//
//    private var sectionBackgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundDark//.opacity(0.5)
//    }
//
//    private var secondaryForegroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.dark.opacity(0.7) : colorSchemeManager.currentScheme.light.opacity(0.7)
//    }
//    private var tileBackgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.tileBackgroundColor : colorSchemeManager.currentScheme.tileBackgroundColor
//    }
//    private var secondaryBackgroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundLight
//    }
//    private var titleForegroundColor: Color {
//        colorScheme == .light ? colorSchemeManager.currentScheme.backgroundLight : colorSchemeManager.currentScheme.backgroundLight
//    }
//
//
//}
