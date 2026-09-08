//
//  DiagnosticsStatus.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/4/26.
//

import Foundation

struct DiagnosticGeofence: Identifiable, Equatable {

    let id: UUID
    let name: String
    
    let latitude: Double
    let longitude: Double

    let radius: Double

    var distance: Double?
    var state: String

    init(
        id: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        distance: Double? = nil,
        state: String = "Unknown"
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.distance = distance
        self.state = state
    }
}


struct DiagnosticsStatus: Equatable {

    var appState: String = "Unknown"

    var locationAuthorization: String = "Unknown"

    var notificationAuthorization: String = "Unknown"

    var latitude: Double?

    var longitude: Double?

    var horizontalAccuracy: Double?

    var lastLocationUpdate: Date?

    var wantToGoCount: Int = 0

    var activeGeofenceCount: Int = 0

    var fallbackRunning: Bool = false

    var lastGeofenceEvent: String?

    var lastArrivalDetected: String?

    var lastNotificationSent: String?

    var lastError: String?

    var geofences: [DiagnosticGeofence] = []
}
