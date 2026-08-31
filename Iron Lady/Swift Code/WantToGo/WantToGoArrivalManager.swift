//
//  WantToGoArrivalManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/28/26.
//

import Foundation
import CoreLocation
import CoreData
import UserNotifications

@MainActor
final class WantToGoArrivalManager:
    NSObject,
    CLLocationManagerDelegate,
    UNUserNotificationCenterDelegate {

    static let shared = WantToGoArrivalManager()

    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()

    private let monitorName = "WaymarXWantToGo"

    private var monitor: CLMonitor?
    private var monitorTask: Task<Void, Never>?
    private var isStartingMonitor = false
    private var locationContinuation:
        CheckedContinuation<CLLocation?, Never>?
    
    private let fallbackNotificationCooldown:
        TimeInterval = 6 * 60 * 60

    private let fallbackNotificationDefaultsPrefix =
        "WantToGoFallbackNotification."
    
    
    private override init() {

        super.init()

        locationManager.delegate = self
        notificationCenter.delegate = self

        registerNotificationCategory()
    }

    // MARK: - Start

    func start() {

        print("")
        print("====================================")
        print("WantToGoArrivalManager START")
        print("====================================")

        print(
            "Location authorization:",
            locationAuthorizationDescription(
                locationManager.authorizationStatus
            )
        )

        requestNotificationPermission()

        requestLocationPermission()

        if CLLocationManager.significantLocationChangeMonitoringAvailable() {

            locationManager
                .startMonitoringSignificantLocationChanges()

            print(
                "WantToGo significant-location fallback started."
            )

        } else {

            print(
                "WantToGo significant-location monitoring unavailable."
            )
        }
        
        Task {
            await startMonitor()
        }
    }

    private func locationAuthorizationDescription(
        _ status: CLAuthorizationStatus
    ) -> String {

        switch status {

        case .notDetermined:
            return "notDetermined"

        case .restricted:
            return "restricted"

        case .denied:
            return "denied"

        case .authorizedAlways:
            return "authorizedAlways"

        case .authorizedWhenInUse:
            return "authorizedWhenInUse"

        @unknown default:
            return "unknown"
        }
    }
    
    private func lastFallbackNotificationDate(
        for breadcrumbID: UUID
    ) -> Date? {

        let key =
            fallbackNotificationDefaultsPrefix
            + breadcrumbID.uuidString

        return UserDefaults.standard
            .object(
                forKey: key
            ) as? Date
    }

    private func saveFallbackNotificationDate(
        _ date: Date,
        for breadcrumbID: UUID
    ) {

        let key =
            fallbackNotificationDefaultsPrefix
            + breadcrumbID.uuidString

        UserDefaults.standard.set(
            date,
            forKey: key
        )
    }
    
    // MARK: - Notification Permission

    private func requestNotificationPermission() {

        notificationCenter.requestAuthorization(
            options: [
                .alert,
                .sound,
                .badge
            ]
        ) { granted, error in

            if let error {
                print(
                    "Notification permission error:",
                    error.localizedDescription
                )
            }

            print(
                "Notification permission granted:",
                granted
            )
        }
    }

    // MARK: - Location Permission

    private func requestLocationPermission() {

        switch locationManager.authorizationStatus {

        case .notDetermined:

            locationManager
                .requestWhenInUseAuthorization()

        case .authorizedWhenInUse:

            locationManager
                .requestAlwaysAuthorization()

        case .authorizedAlways:

            break

        case .denied,
             .restricted:

            print(
                "Location permission unavailable."
            )

        @unknown default:

            break
        }
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        switch manager.authorizationStatus {

        case .authorizedWhenInUse:

            manager
                .requestAlwaysAuthorization()

        case .authorizedAlways:

            Task {
                await startMonitor()
            }

        default:

            break
        }
    }

    private func getCurrentLocation() async -> CLLocation? {

        if let currentLocation =
            locationManager.location {

            return currentLocation
        }

        return await withCheckedContinuation {
            continuation in

            locationContinuation =
                continuation

            locationManager.requestLocation()
        }
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard let location =
            locations.last
        else {
            return
        }


        print("")
        print(
            "WantToGo location update:",
            location.coordinate.latitude,
            location.coordinate.longitude
        )

        print(
            "Location accuracy:",
            location.horizontalAccuracy
        )


        // MARK: - Complete Any Pending One-Time Location Request

        if let continuation =
            locationContinuation {

            continuation.resume(
                returning: location
            )

            locationContinuation = nil
        }


        // MARK: - Run Fallback Proximity Check

        Task {

            await checkWantToGoProximity(
                from: location
            )
        }
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {

        print(
            "WantToGo location request failed:",
            error.localizedDescription
        )

        locationContinuation?
            .resume(
                returning: nil
            )

        locationContinuation = nil
    }
    
    // MARK: - WantToGo Fallback Proximity Check

    private func checkWantToGoProximity(
        from currentLocation: CLLocation
    ) async {

        guard currentLocation.horizontalAccuracy >= 0 else {

            print(
                "WantToGo fallback ignored invalid location accuracy."
            )

            return
        }


        let context =
            PersistenceController
                .shared
                .container
                .newBackgroundContext()


        let nearbyDestinations:
            [(id: UUID, name: String, distance: Double, radius: Double)] =
            await context.perform {

                let request:
                    NSFetchRequest<Breadcrumb> =
                        Breadcrumb.fetchRequest()

                request.predicate =
                    NSPredicate(
                        format:
                            "isWantToGo == YES"
                    )

                do {

                    let breadcrumbs =
                        try context.fetch(
                            request
                        )

                    return breadcrumbs
                        .compactMap { breadcrumb in

                            guard let id =
                                    breadcrumb.id
                            else {

                                return nil
                            }


                            let destinationLocation =
                                CLLocation(
                                    latitude:
                                        breadcrumb.latitude,
                                    longitude:
                                        breadcrumb.longitude
                                )


                            let distance =
                                currentLocation.distance(
                                    from:
                                        destinationLocation
                                )


                            let radius =
                                breadcrumb.arrivalRadius?
                                    .doubleValue
                                ?? 300.0


                            guard distance <= radius
                            else {

                                return nil
                            }


                            return (
                                id: id,
                                name:
                                    breadcrumb.name
                                    ?? "Unnamed Destination",
                                distance:
                                    distance,
                                radius:
                                    radius
                            )
                        }

                } catch {

                    print(
                        "WantToGo fallback fetch failed:",
                        error.localizedDescription
                    )

                    return []
                }
            }


        guard !nearbyDestinations.isEmpty
        else {

            print(
                "WantToGo fallback: no destinations within arrival radius."
            )

            return
        }


        print("")
        print(
            "WantToGo fallback found",
            nearbyDestinations.count,
            "nearby destination(s)."
        )


        for destination
            in nearbyDestinations {

            print(
                "Nearby:",
                destination.name
            )

            print(
                "Distance:",
                Int(destination.distance),
                "meters"
            )

            print(
                "Arrival radius:",
                Int(destination.radius),
                "meters"
            )


            // MARK: - Notification Cooldown

            if let lastNotification =
                lastFallbackNotificationDate(
                    for: destination.id
                ) {

                let elapsed =
                    Date().timeIntervalSince(
                        lastNotification
                    )

                if elapsed <
                    fallbackNotificationCooldown {

                    print(
                        "Fallback notification suppressed by cooldown:",
                        destination.name
                    )

                    continue
                }
            }


            print(
                "Fallback sending arrival notification:",
                destination.name
            )


            await sendArrivalNotification(
                breadcrumbID:
                    destination.id
            )


            saveFallbackNotificationDate(
                Date(),
                for: destination.id
            )
        }
    }
    
    // MARK: - Start Monitor

    private func startMonitor() async {
        
        print("")
        print("WantToGo: startMonitor() called")

        print(
            "Authorization:",
            locationAuthorizationDescription(
                locationManager.authorizationStatus
            )
        )

        print(
            "Existing monitor:",
            monitor != nil
        )

        print(
            "Monitor starting:",
            isStartingMonitor
        )
        
        guard monitor == nil,
              !isStartingMonitor
        else {
            return
        }

        isStartingMonitor = true

        let newMonitor =
            await CLMonitor(
                monitorName
            )

        monitor = newMonitor
        
        print(
            "WantToGo: CLMonitor created successfully"
        )

        let existingIdentifiers =
            await newMonitor.identifiers

        print(
            "Existing monitored condition count:",
            existingIdentifiers.count
        )

        for identifier in existingIdentifiers {

            print(
                "Existing monitor identifier:",
                identifier
            )
        }

        isStartingMonitor = false
        
        monitorTask =
            Task { [weak self] in

                guard let self else {
                    return
                }

                do {

                    for try await event in await newMonitor.events {

                        await self.handle(
                            event
                        )
                    }

                } catch {

                    print(
                        "Want-to-Go monitor event error:",
                        error.localizedDescription
                    )
                }
            }
        
        await restoreWantToGoGeofences()
    }

    // MARK: - Restore Existing Want-to-Go Pins

    private func restoreWantToGoGeofences() async {

        guard let monitor else {

            print(
                "WantToGo restore failed: monitor is unavailable."
            )

            return
        }

        let currentLocation =
            await getCurrentLocation()

        if let currentLocation {

            print("")
            print(
                "WantToGo current location:",
                currentLocation.coordinate.latitude,
                currentLocation.coordinate.longitude
            )

        } else {

            print(
                "WantToGo current location unavailable."
            )
        }

        let context =
            PersistenceController
                .shared
                .container
                .newBackgroundContext()


        let breadcrumbData: [
            (
                id: UUID,
                name: String?,
                latitude: Double,
                longitude: Double,
                radius: Double
            )
        ] = await context.perform {

            let request:
                NSFetchRequest<Breadcrumb> =
                    Breadcrumb.fetchRequest()

            request.predicate =
                NSPredicate(
                    format:
                        "isWantToGo == YES"
                )

            do {

                let breadcrumbs =
                    try context.fetch(
                        request
                    )


                let sortedBreadcrumbs:
                    [Breadcrumb]


                if let currentLocation {

                    sortedBreadcrumbs =
                        breadcrumbs.sorted {
                            first,
                            second in

                            let firstLocation =
                                CLLocation(
                                    latitude:
                                        first.latitude,
                                    longitude:
                                        first.longitude
                                )

                            let secondLocation =
                                CLLocation(
                                    latitude:
                                        second.latitude,
                                    longitude:
                                        second.longitude
                                )

                            let firstDistance =
                                firstLocation.distance(
                                    from:
                                        currentLocation
                                )

                            let secondDistance =
                                secondLocation.distance(
                                    from:
                                        currentLocation
                                )

                            return firstDistance <
                                secondDistance
                        }

                } else {

                    sortedBreadcrumbs =
                        breadcrumbs.sorted {

                            ($0.wantToGoDate ??
                                .distantPast)
                            >
                            ($1.wantToGoDate ??
                                .distantPast)
                        }
                }


                return sortedBreadcrumbs
                    .prefix(20)
                    .compactMap { breadcrumb in

                        guard let id =
                                breadcrumb.id
                        else {

                            return nil
                        }

                        return (
                            id: id,
                            name:
                                breadcrumb.name,
                            latitude:
                                breadcrumb.latitude,
                            longitude:
                                breadcrumb.longitude,
                            radius:
                                breadcrumb.arrivalRadius?
                                    .doubleValue
                                ?? 300.0
                        )
                    }

            } catch {

                print(
                    "Failed loading Want-to-Go pins:",
                    error.localizedDescription
                )

                return []
            }
        }

        print("")
        print(
            "WantToGo destinations loaded for monitoring:",
            breadcrumbData.count
        )


        // MARK: - Build Set Of Current Want-to-Go IDs

        let currentIdentifiers =
            Set(
                breadcrumbData.map {
                    $0.id.uuidString
                }
            )


        // MARK: - Find Existing CLMonitor Conditions

        let existingIdentifiers =
            await monitor.identifiers


        print(
            "Existing monitored conditions before cleanup:",
            existingIdentifiers.count
        )


        // MARK: - Remove Stale Geofences

        let staleIdentifiers =
            existingIdentifiers.filter {
                !currentIdentifiers.contains(
                    $0
                )
            }


        print(
            "Stale WantToGo geofences found:",
            staleIdentifiers.count
        )


        for identifier
            in staleIdentifiers {

            print(
                "Removing stale WantToGo geofence:",
                identifier
            )

            await monitor.remove(
                identifier
            )
        }


        // MARK: - Add Current Want-to-Go Geofences

        for item in breadcrumbData {

            await addGeofence(
                id: item.id,
                name: item.name,
                latitude:
                    item.latitude,
                longitude:
                    item.longitude,
                radius:
                    item.radius
            )
        }


        // MARK: - Verify Final Monitor State

        let finalIdentifiers =
            await monitor.identifiers


        print("")
        print(
            "WantToGo geofence reconciliation complete."
        )

        print(
            "Current WantToGo destinations:",
            breadcrumbData.count
        )

        print(
            "Stale geofences removed:",
            staleIdentifiers.count
        )

        print(
            "Final monitored condition count:",
            finalIdentifiers.count
        )

        for identifier
            in finalIdentifiers {

            print(
                "Final monitor identifier:",
                identifier
            )
        }
    }
    // MARK: - Add Geofence From Breadcrumb

    func addGeofence(
        for breadcrumb: Breadcrumb
    ) async {

        guard let id =
                breadcrumb.id
        else {
            return
        }

        await addGeofence(
            id: id,
            name: breadcrumb.name,
            latitude: breadcrumb.latitude,
            longitude: breadcrumb.longitude,
            radius:
                breadcrumb.arrivalRadius?
                    .doubleValue
                ?? 300.0
        )
    }

    // MARK: - Add Geofence

    private func addGeofence(
        id: UUID,
        name: String?,
        latitude: Double,
        longitude: Double,
        radius: Double
    ) async {

        guard let monitor else {
            return
        }

        let identifier =
            id.uuidString

        let coordinate =
            CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )

        let condition =
            CLMonitor
                .CircularGeographicCondition(
                    center: coordinate,
                    radius: radius
                )

        await monitor.add(
            condition,
            identifier: identifier
        )

        print("")
        print("WantToGo geofence added")

        print(
            "Name:",
            name ?? "Unnamed"
        )

        print(
            "Identifier:",
            identifier
        )

        print(
            "Latitude:",
            latitude
        )

        print(
            "Longitude:",
            longitude
        )

        print(
            "Radius:",
            radius
        )
    }

    // MARK: - Remove Geofence

    func removeGeofence(
        breadcrumbID: UUID
    ) async {

        guard let monitor else {
            return
        }

        await monitor.remove(
            breadcrumbID.uuidString
        )
    }

    // MARK: - Handle Monitor Event

    // MARK: - Handle Monitor Event

    private func handle(
        _ event: CLMonitor.Event
    ) async {

        print("")
        print("====================================")
        print("WantToGo MONITOR EVENT")
        print("====================================")

        print(
            "Identifier:",
            event.identifier
        )

        print(
            "Date:",
            event.date
        )

        print(
            "State:",
            String(
                describing: event.state
            )
        )

        print(
            "accuracyLimited:",
            event.accuracyLimited
        )

        print(
            "authorizationDenied:",
            event.authorizationDenied
        )

        print(
            "authorizationDeniedGlobally:",
            event.authorizationDeniedGlobally
        )

        print(
            "authorizationRequestInProgress:",
            event.authorizationRequestInProgress
        )

        print(
            "authorizationRestricted:",
            event.authorizationRestricted
        )

        print(
            "conditionLimitExceeded:",
            event.conditionLimitExceeded
        )

        print(
            "conditionUnsupported:",
            event.conditionUnsupported
        )

        print(
            "insufficientlyInUse:",
            event.insufficientlyInUse
        )

        print(
            "persistenceUnavailable:",
            event.persistenceUnavailable
        )

        print(
            "serviceSessionRequired:",
            event.serviceSessionRequired
        )

        guard event.state == .satisfied else {

            print(
                "WantToGo condition is NOT satisfied."
            )

            return
        }

        print(
            "WantToGo condition SATISFIED."
        )

        guard let breadcrumbID =
            UUID(
                uuidString: event.identifier
            )
        else {

            print(
                "Invalid WantToGo monitor identifier:",
                event.identifier
            )

            return
        }

        print(
            "Sending arrival notification for:",
            breadcrumbID
        )

        await sendArrivalNotification(
            breadcrumbID: breadcrumbID
        )
    }
    
    
    // MARK: - Notification Actions

    private func registerNotificationCategory() {

        let hereAction =
            UNNotificationAction(
                identifier:
                    "WANT_TO_GO_HERE",
                title:
                    "I'm Here",
                options:
                    [.foreground]
            )

        let notYetAction =
            UNNotificationAction(
                identifier:
                    "WANT_TO_GO_NOT_YET",
                title:
                    "Not Yet",
                options:
                    []
            )

        let category =
            UNNotificationCategory(
                identifier:
                    "WANT_TO_GO_ARRIVAL",
                actions: [
                    hereAction,
                    notYetAction
                ],
                intentIdentifiers: [],
                options: []
            )

        notificationCenter
            .setNotificationCategories(
                [category]
            )
    }

    // MARK: - Send Arrival Notification

    private func sendArrivalNotification(
        breadcrumbID: UUID
    ) async {

        let context =
            PersistenceController
                .shared
                .container
                .newBackgroundContext()

        let destinationName: String =
            await context.perform {

                let request:
                    NSFetchRequest<Breadcrumb> =
                    Breadcrumb.fetchRequest()

                request.fetchLimit = 1

                request.predicate =
                    NSPredicate(
                        format:
                            "id == %@",
                        breadcrumbID
                            as CVarArg
                    )

                if let breadcrumb =
                    try? context.fetch(
                        request
                    ).first {

                    return breadcrumb.name
                        ?? "your destination"
                }

                return "your destination"
            }

        let content =
            UNMutableNotificationContent()

        content.title =
            "Looks like you made it!"

        content.body =
            "Are you at \(destinationName)?"

        content.sound =
            .default

        content.categoryIdentifier =
            "WANT_TO_GO_ARRIVAL"

        content.userInfo = [
            "breadcrumbID":
                breadcrumbID.uuidString
        ]

        let request =
            UNNotificationRequest(
                identifier:
                    "arrival-\(breadcrumbID.uuidString)",
                content: content,
                trigger: nil
            )

        do {

            try await notificationCenter
                .add(request)
            
            print(
                "Arrival notification successfully submitted:",
                breadcrumbID
            )

        } catch {

            print(
                "Arrival notification failed:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Notification Response

    nonisolated func userNotificationCenter(
        _ center:
            UNUserNotificationCenter,
        didReceive response:
            UNNotificationResponse,
        withCompletionHandler
            completionHandler:
                @escaping () -> Void
    ) {

        guard let idString =
                response.notification
                    .request
                    .content
                    .userInfo[
                        "breadcrumbID"
                    ] as? String,
              let breadcrumbID =
                UUID(
                    uuidString:
                        idString
                )
        else {

            completionHandler()
            return
        }

        let actionIdentifier =
            response.actionIdentifier

        if actionIdentifier ==
            "WANT_TO_GO_HERE" {

            Task { @MainActor in

                await self.markAsVisited(
                    breadcrumbID:
                        breadcrumbID
                )

                completionHandler()
            }

        } else {

            completionHandler()
        }
    }

    func markAsVisited(
        _ breadcrumb: Breadcrumb
    ) async {

        guard let breadcrumbID = breadcrumb.id else {
            print(
                "Unable to mark Want-to-Go as visited: missing Breadcrumb ID."
            )
            return
        }

        await markAsVisited(
            breadcrumbID: breadcrumbID
        )
    }
    
    // MARK: - Mark As Visited

    private func markAsVisited(
        breadcrumbID: UUID
    ) async {

        let context =
            PersistenceController
                .shared
                .container
                .newBackgroundContext()

        let converted =
            await context.perform {

                let request:
                    NSFetchRequest<Breadcrumb> =
                    Breadcrumb.fetchRequest()

                request.fetchLimit = 1

                request.predicate =
                    NSPredicate(
                        format:
                            "id == %@",
                        breadcrumbID
                            as CVarArg
                    )

                do {

                    guard let breadcrumb =
                        try context.fetch(
                            request
                        ).first
                    else {
                        return false
                    }

                    breadcrumb.isWantToGo =
                        false

                    breadcrumb.visitedDate =
                        Date()

                    breadcrumb.dateDropped =
                        Date()

                    try context.save()

                    print(
                        "Want-to-Go converted:",
                        breadcrumb.name
                            ?? "Unnamed"
                    )

                    return true

                } catch {

                    print(
                        "Arrival conversion failed:",
                        error.localizedDescription
                    )

                    return false
                }
            }

        if converted {

            await removeGeofence(
                breadcrumbID:
                    breadcrumbID
            )

            let notificationID =
                "arrival-\(breadcrumbID.uuidString)"

            notificationCenter
                .removePendingNotificationRequests(
                    withIdentifiers: [
                        notificationID
                    ]
                )

            notificationCenter
                .removeDeliveredNotifications(
                    withIdentifiers: [
                        notificationID
                    ]
                )
        }
    }

    // MARK: - Show Notifications In Foreground

    nonisolated func userNotificationCenter(
        _ center:
            UNUserNotificationCenter,
        willPresent notification:
            UNNotification
    ) async
        -> UNNotificationPresentationOptions {

        [
            .banner,
            .list,
            .sound
        ]
    }
}
