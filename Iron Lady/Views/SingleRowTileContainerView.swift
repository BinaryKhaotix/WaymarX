//
//  SingleRowTileContainerView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/13/24.
//
import SwiftUI

struct SingleRowTileContainerView<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let content: (Item) -> Content
    
    private let spacing: CGFloat = 10
    private let verticalPaddingForShadow: CGFloat = 10
    private let horizontalInset: CGFloat = 0          // keep aligned with card content
    private let clipCornerRadius: CGFloat = 14        // subtle, matches your inner chips
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            if !title.isEmpty {
                Text(title)
                    .font(.title2)
                    .bold()
                    .foregroundColor(Color("Dark Orange"))
            }
            GeometryReader { geo in

                let available = geo.size.width
                let calculatedWidth = (available - (spacing * 2)) / 3

                let tileWidth = min(calculatedWidth, 140)
                let tileHeight = tileWidth

                ScrollView(.horizontal, showsIndicators: false) {

                    HStack(spacing: spacing) {

                        ForEach(items) { item in

                            content(item)
                                .frame(
                                    width: tileWidth,
                                    height: tileHeight
                                )
                        }
                    }
                    .padding(.bottom, 25)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .scrollIndicators(.hidden)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: clipCornerRadius,
                        style: .continuous
                    )
                )
                .contentShape(Rectangle())
            }
            .frame(height: 120)
        }
    }
}
    //







//import SwiftUI
//
//struct SingleRowTileContainerView<Item: Identifiable, Content: View>: View {
//    let title: String
//    let items: [Item]
//    let content: (Item) -> Content
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//
//            if !title.isEmpty {
//                Text(title)
//                    .font(.title2)
//                    .bold()
//                    .padding(.horizontal)
//                    .foregroundColor(Color("Dark Orange"))
//            }
//
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 10) {
//                    ForEach(items) { item in
//                        content(item)
//                            // Give the shadow room inside the scroll content
//                            .padding(.vertical, 8)
//                    }
//                }
//                .padding(.horizontal)
//                .padding(.vertical, 6) // extra breathing room for shadows
//            }
//            .scrollClipDisabled(true) // ⭐️ THE FIX: don’t clip shadows
//        }
//        .padding(.vertical, 10)
//    }
//}




//import SwiftUI
//
//struct SingleRowTileContainerView<Item: Identifiable, Content: View>: View {
//    let title: String
//    let items: [Item]
//    let content: (Item) -> Content
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            // Title Section
//            if !title.isEmpty {
//                Text(title)
//                    .font(.title2)
//                    .bold()
//                    .padding(.horizontal)
//                    .foregroundColor(Color("Dark Orange"))
//            }
//
//            // Single Row of Tiles
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 10) {
//                    ForEach(items) { item in
//                        content(item)
//                            .frame(width: 100, height: 100) // Tile size for single row
//                            //.background(Color.gray.opacity(0.2))
//                            .cornerRadius(10)
//                            //.shadow(radius: 5)
//                    }
//                }
//                .padding(.horizontal)
//            }
//        }
//        .padding(.vertical, 10) // Match spacing with other sections
//    }
//}


//import SwiftUI
//
//
//struct SingleRowTileContainerView<Item: Identifiable, Content: View>: View {
//    let title: String
//    let items: [Item]
//    let content: (Item) -> Content
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 5) {
//            // Title Section
//            Text(title)
//                .font(.title2)
//                .bold()
//                .padding(.top, 20)
//
//            // Horizontal ScrollView for Single Row
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 5) { // Space between tiles
//                    ForEach(items) { item in
//                        content(item)
//                            .frame(width: 80, height: 80) // Fixed size to ensure visibility
//                    }
//                }
//                .padding(.horizontal, 25) // Padding inside the container
//            }
//        }
//        .padding(.vertical, 15) // Padding around the container
//    }
//}
