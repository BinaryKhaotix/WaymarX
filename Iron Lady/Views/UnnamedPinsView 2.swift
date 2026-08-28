//
//  UnnamedPinsView 2.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/16/26.
//


import SwiftUI
import CoreData

public struct UnnamedPinsView: View {
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var locationManager: LocationManager

    public let breadcrumbs: [Breadcrumb]

    public var body: some View {
        ZStack {
            Color(.white).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unsaved Pins")
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color("Dark Blue"))
                        .padding(.horizontal)

                    Text("\(breadcrumbs.count) Pin(s)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                        spacing: 10
                    ) {
                        ForEach(breadcrumbs, id: \.objectID) { breadcrumb in
                            Button {
                                navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
                            } label: {
                                UnnamedPinTile(breadcrumb: breadcrumb)
                                    .environmentObject(locationManager)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Unsaved Pins")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    navigationModel.pop()
                } label: {
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
}

// MARK: - Tile for Unnamed Pins (own style, heart only if favorite)
private struct UnnamedPinTile: View {
    @EnvironmentObject var locationManager: LocationManager
    let breadcrumb: Breadcrumb

    private var displayName: String {
        let name = (breadcrumb.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed Pin" : name
    }

    private var isFavorite: Bool {
        // ✅ CHANGE THIS KEY if your Core Data field is not named "isFavorite"
        // Example alternatives:
        // (breadcrumb.value(forKey: "favorite") as? Bool) ?? false
        // (breadcrumb.value(forKey: "isFav") as? Bool) ?? false
        (breadcrumb.value(forKey: "isFavorite") as? Bool) ?? false
    }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Background Image
            if let photoFileName = breadcrumb.photoURL,
               let image = loadImage(from: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipped()
            } else {
                Color.gray
                    .opacity(0.15)
                    .frame(width: 110, height: 110)
            }

            // Readability overlay
            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Top badges row
            HStack(spacing: 6) {
                Text("UNSAVED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("Dark Blue"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color("Dark Orange").opacity(0.92))
                    .clipShape(Capsule())

                Spacer(minLength: 0)

                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Circle())
                }
            }
            .padding(8)

            // Bottom name overlay
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }
                .padding(8)
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 5)
    }
}
