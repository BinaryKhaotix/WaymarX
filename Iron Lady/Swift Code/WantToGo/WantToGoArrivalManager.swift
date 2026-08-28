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

    private override init() {

        super.init()

        locationManager.delegate = self
        notificationCenter.delegate = self

        registerNotificationCategory()
    }

    // MARK: - Start

    func start() {

        requestNotificationPermission()
        requestLocationPermission()

        Task {
            await startMonitor()
        }
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

    // MARK: - Start Monitor

    private func startMonitor() async {

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

        monitor =
            newMonitor

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

                return breadcrumbs
                    .prefix(20)
                    .compactMap { breadcrumb in

                        guard let id =
                                breadcrumb.id
                        else {
                            return nil
                        }

                        return (
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

            } catch {

                print(
                    "Failed loading Want-to-Go pins:",
                    error.localizedDescription
                )

                return []
            }
        }

        for item in breadcrumbData {

            await addGeofence(
                id: item.id,
                name: item.name,
                latitude: item.latitude,
                longitude: item.longitude,
                radius: item.radius
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

        print(
            "Monitoring Want-to-Go:",
            name ?? identifier
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

    private func handle(
        _ event: CLMonitor.Event
    ) async {

        guard event.state ==
                .satisfied
        else {
            return
        }

        guard let breadcrumbID =
                UUID(
                    uuidString:
                        event.identifier
                )
        else {
            return
        }

        await sendArrivalNotification(
            breadcrumbID:
                breadcrumbID
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

                await self.confirmArrival(
                    breadcrumbID:
                        breadcrumbID
                )

                completionHandler()
            }

        } else {

            completionHandler()
        }
    }

    // MARK: - Confirm Arrival

    private func confirmArrival(
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
