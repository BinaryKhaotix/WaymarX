//
//  DiagnosticsStore.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/4/26.
//

import Foundation
import SwiftUI
import CoreLocation

@MainActor
final class DiagnosticsStore: ObservableObject {

    static let shared = DiagnosticsStore()

    @Published private(set) var entries: [DiagnosticsEntry] = []
    @Published var status = DiagnosticsStatus()

    private let storageKey = "WaymarX.DiagnosticsLog"

    private init() {
        load()
    }

    func log(
        _ message: String,
        category: String = "General"
    ) {

        let entry =
            DiagnosticsEntry(
                category: category,
                message: message
            )

        entries.append(entry)

        // Keep the log from growing forever.
        if entries.count > 500 {
            entries.removeFirst(
                entries.count - 500
            )
        }

        save()

        print(
            "[\(category)] \(message)"
        )
    }

    func clear() {

        entries.removeAll()

        UserDefaults.standard.removeObject(
            forKey: storageKey
        )
    }
    
    func updateAppState(_ value: String) {
        status.appState = value
    }

    func updateLocationAuthorization(_ value: String) {
        status.locationAuthorization = value
    }

    func updateNotificationAuthorization(_ value: String) {
        status.notificationAuthorization = value
    }
    
    private func updateGeofenceDistances(
        latitude: Double,
        longitude: Double
    ) {

        let currentLocation =
            CLLocation(
                latitude: latitude,
                longitude: longitude
            )

        for index in status.geofences.indices {

            let geofence =
                status.geofences[index]

            let destinationLocation =
                CLLocation(
                    latitude: geofence.latitude,
                    longitude: geofence.longitude
                )

            status.geofences[index].distance =
                currentLocation.distance(
                    from: destinationLocation
                )
        }
    }
    
    func updateLocation(
        latitude: Double,
        longitude: Double,
        accuracy: Double
    ) {

        status.latitude = latitude
        status.longitude = longitude
        status.horizontalAccuracy = accuracy
        status.lastLocationUpdate = Date()

        updateGeofenceDistances(
            latitude: latitude,
            longitude: longitude
        )
    }


    func updateWantToGoCount(_ count: Int) {
        status.wantToGoCount = count
    }


    func updateFallbackRunning(_ running: Bool) {
        status.fallbackRunning = running
    }


    func updateGeofences(
        _ geofences: [DiagnosticGeofence]
    ) {

        status.geofences = geofences
        status.activeGeofenceCount =
            geofences.count
    }

    func removeGeofence(
        id: UUID
    ) {

        status.geofences.removeAll {
            $0.id == id
        }

        status.activeGeofenceCount =
            status.geofences.count
    }

    func updateGeofenceState(
        id: UUID,
        state: String
    ) {

        guard let index =
            status.geofences.firstIndex(
                where: { $0.id == id }
            )
        else {
            return
        }

        status.geofences[index].state = state
    }


    func recordGeofenceEvent(_ value: String) {
        status.lastGeofenceEvent = value
    }


    func recordArrival(_ value: String) {
        status.lastArrivalDetected = value
    }


    func recordNotification(_ value: String) {
        status.lastNotificationSent = value
    }


    func recordError(_ value: String) {
        status.lastError = value
    }

    private func save() {

        do {

            let data =
                try JSONEncoder()
                    .encode(entries)

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )

        } catch {

            print(
                "Diagnostics save failed:",
                error.localizedDescription
            )
        }
    }

    private func load() {

        guard let data =
            UserDefaults.standard.data(
                forKey: storageKey
            )
        else {
            return
        }

        do {

            entries =
                try JSONDecoder()
                    .decode(
                        [DiagnosticsEntry].self,
                        from: data
                    )

        } catch {

            print(
                "Diagnostics load failed:",
                error.localizedDescription
            )
        }
    }
}
