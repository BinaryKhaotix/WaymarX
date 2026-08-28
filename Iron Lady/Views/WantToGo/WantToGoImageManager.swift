//
//  WantToGoImageManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/28/26.
//

import Foundation
import MapKit
import UIKit

final class WantToGoImageManager {

    static let shared = WantToGoImageManager()

    private init() {}

    // MARK: - Public

    func createDestinationImage(
        coordinate: CLLocationCoordinate2D
    ) async -> String? {

        // First choice: Look Around
        if let lookAroundImage =
            await createLookAroundImage(
                coordinate: coordinate
            ) {

            return saveImage(
                lookAroundImage,
                prefix: "WantToGo-LookAround"
            )
        }

        // Fallback: standard map snapshot
        if let mapImage =
            await createMapSnapshot(
                coordinate: coordinate
            ) {

            return saveImage(
                mapImage,
                prefix: "WantToGo-Map"
            )
        }

        return nil
    }

    // MARK: - Look Around

    private func createLookAroundImage(
        coordinate: CLLocationCoordinate2D
    ) async -> UIImage? {

        let request =
            MKLookAroundSceneRequest(
                coordinate: coordinate
            )

        do {

            guard let scene =
                try await request.scene
            else {
                return nil
            }

            let options =
                MKLookAroundSnapshotter.Options()

            options.size =
                CGSize(
                    width: 900,
                    height: 600
                )

            let snapshotter =
                MKLookAroundSnapshotter(
                    scene: scene,
                    options: options
                )

            let snapshot =
                try await snapshotter.snapshot

            return snapshot.image

        } catch {

            print(
                "Look Around unavailable:",
                error.localizedDescription
            )

            return nil
        }
    }

    // MARK: - Map Snapshot

    private func createMapSnapshot(
        coordinate: CLLocationCoordinate2D
    ) async -> UIImage? {

        let options =
            MKMapSnapshotter.Options()

        options.region =
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1800,
                longitudinalMeters: 1800
            )

        options.size =
            CGSize(
                width: 900,
                height: 600
            )

        options.preferredConfiguration =
            MKStandardMapConfiguration(
                elevationStyle: .realistic
            )

        let snapshotter =
            MKMapSnapshotter(
                options: options
            )

        do {

            let snapshot =
                try await snapshotter.start()

            return snapshot.image

        } catch {

            print(
                "Map snapshot failed:",
                error.localizedDescription
            )

            return nil
        }
    }

    // MARK: - Save Image

    private func saveImage(
        _ image: UIImage,
        prefix: String
    ) -> String? {

        guard let data =
            image.jpegData(
                compressionQuality: 0.85
            )
        else {
            return nil
        }

        guard let documentsDirectory =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            return nil
        }

        let fileName =
            "\(prefix)-\(UUID().uuidString).jpg"

        let fileURL =
            documentsDirectory.appendingPathComponent(
                fileName
            )

        do {

            try data.write(
                to: fileURL,
                options: .atomic
            )

            return fileName

        } catch {

            print(
                "Destination image save failed:",
                error.localizedDescription
            )

            return nil
        }
    }
}
