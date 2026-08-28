//
//  FavoriteCrumbTile.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/24/25.
//
import SwiftUI

struct FavoriteCrumbTile: View {
    let breadcrumb: Breadcrumb

    /// Favorites view will use the default (true).
    /// Recent view should pass false and handle its own overlays.
    var showHeart: Bool = true

    var body: some View {
        ZStack {
            // --- Base tile content (this stays "inside" the 100x100) ---
            ZStack {

                // Background Image
                if let photoFileName = breadcrumb.photoURL,
                   let image = loadImage(from: photoFileName) {

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipped()

                } else {

                    Color.gray
                        .opacity(0.2)
                        .frame(width: 100, height: 100)
                }

                // Name Overlay
                Text(breadcrumb.name ?? "Unnamed Pin")
                    .font(.caption)
                    .foregroundStyle(.white, .black)
                    .bold()
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(2)
                    .cornerRadius(5)
                    .padding(2)
            }
            .frame(width: 100, height: 100)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            .shadow(
                radius: 5,
                x: 5,
                y: 5
            )

            // --- Heart (allowed to hang OUTSIDE the 100x100) ---
            if showHeart {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            // Overhang bottom-right
                            .offset(x: 10, y: 10)
                            .allowsHitTesting(false)
                    }
                }
                // This frame defines the base tile area, but the offset lets the heart overflow.
                .frame(width: 100, height: 100)
            }
        }
        // IMPORTANT: do NOT clip here, or the heart can't overhang.
        .frame(width: 100, height: 100)
    }
}



//import SwiftUI
//
//struct FavoriteCrumbTile: View {
//    let breadcrumb: Breadcrumb
//
//    var body: some View {
//        ZStack {
//            // Background Image
//            if let photoFileName = breadcrumb.photoURL, let image = loadImage(from: photoFileName) {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 100, height: 100) // Square tile dimensions
//                    .clipped()
//            } else {
//                // Placeholder for missing images
//                Color.gray
//                    .opacity(0.2)
//                    .frame(width: 100, height: 100)
//            }
//
//            // Name Overlay
//            Text(breadcrumb.name ?? "Unnamed Pin")
//                .font(.caption)
//                .foregroundStyle(.white, .black)
//                .bold()
//                .multilineTextAlignment(.center)
//                .lineLimit(3)
//                .padding(2)
//                .cornerRadius(5)
//                .padding(2) // Padding to keep the text away from tile edges
//        }
//        .frame(width: 100, height: 100) // Fixed square dimensions
//        .cornerRadius(10) // Rounded corners
//        .shadow(radius: 5, x: 5, y: 5) // Shadow for the tile
//        .overlay(
//            // Little heart badge at bottom edge
//            Image(systemName: "heart.fill")
//                .font(.system(size: 10, weight: .bold))
//                .foregroundColor(.red)
//                .padding(6)
//                .background(Color.white.opacity(0.82))
//                .clipShape(Circle())
//                .shadow(radius: 2, x: 1, y: 1)
//                .padding(6)
//                .offset(x: 10, y: 10),
//            alignment: .bottomTrailing
//        )
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
