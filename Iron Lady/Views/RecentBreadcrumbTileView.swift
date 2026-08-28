//
//  RecentBreadcrumbTileView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/13/24.
//

import SwiftUI
import UIKit

struct RecentBreadcrumbTileView: View {
    let breadcrumb: Breadcrumb
    let isFavorite: Bool

    private let tileSize: CGFloat = 100
    private let cornerRadius: CGFloat = 10

    private var displayName: String {
        let name = (breadcrumb.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed Pin" : name
    }

    private var relativeTime: String? {
        guard let date = breadcrumb.dateDropped else { return nil }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        ZStack {
            // Content (clipped)
            ZStack {
                if let photoFileName = breadcrumb.photoURL,
                   let image = loadImage(from: photoFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: tileSize, height: tileSize)
                        .clipped()
                } else {
                    Color.gray
                        .opacity(0.2)
                        .frame(width: tileSize, height: tileSize)
                }

                Text(displayName)
                    .font(.caption)
                    .foregroundStyle(.white, .black)
                    .bold()
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(2)
                    .cornerRadius(5)
                    .padding(2)
            }
            .frame(width: tileSize, height: tileSize)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(width: tileSize, height: tileSize)

        // ✅ Shadow lives on a REAL background shape behind the clipped content
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.systemBackground)) // opaque = shadow always works
                .shadow(radius: 5, x: 5, y: 5) // diagnostic
        )

        // Time badge
        .overlay(
            Group {
                if let t = relativeTime {
                    Text(t)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                        .shadow(radius: 2, x: 1, y: 1)
                        .padding(6)
                }
            },
            alignment: .topLeading
        )

        // Heart badge
        .overlay(
            Group {
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Circle())
                        .shadow(radius: 2, x: 1, y: 1)
                        .padding(6)
                        .offset(x: 10, y: 10)
                }
            },
            alignment: .bottomTrailing
        )
    }

    private func loadImage(from fileName: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
