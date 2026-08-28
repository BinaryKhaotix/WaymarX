//
//  TileContainerVerticalView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/15/25.
//

import SwiftUI

struct TileContainerVerticalView<Item: Identifiable, Content: View>: View {
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
                .foregroundColor(Color("Dark Orange"))

            // Dynamic Grid Layout
            GeometryReader { geometry in
                let tileSize = (geometry.size.width - 60) / 3 // Adjust for padding (20 horizontal padding on both sides)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: tileSize, height: tileSize) // Square tiles
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
                .padding(.horizontal, 20) // Padding inside the container
            }
            .frame(minHeight: calculateHeight(for: items.count)) // Adjust height dynamically
        }
        .padding(.vertical, 10) // Padding around the container
    }

    // Calculate height for rows of three
    private func calculateHeight(for itemCount: Int) -> CGFloat {
        let rows = ceil(Double(itemCount) / 3.0)
        return CGFloat(rows * 120 + (rows - 1) * 10) // Tile height 120, spacing 10
    }
}


