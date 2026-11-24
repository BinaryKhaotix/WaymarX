//
//  MarketingDemoData.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/19/26.
//

#if DEBUG

import Foundation
import CoreData
import UIKit

enum MarketingDemoData {

    // MARK: - Public Functions

    static func load(context: NSManagedObjectContext) {

        guard !marketingDataExists(context: context) else {
            print("🟡 Marketing demo data already exists.")
            return
        }

        print("🟢 Loading marketing demo data...")

        // Groups
        let surfGroup = fetchOrCreateGroup(
            named: "Surf Spots",
            description: "Favorite breaks and beaches worth remembering.",
            context: context
        )

        let outdoorsGroup = fetchOrCreateGroup(
            named: "Outdoor Adventures",
            description: "Trails, viewpoints and places to explore.",
            context: context
        )

        let foodGroup = fetchOrCreateGroup(
            named: "Food & Stops",
            description: "Restaurants and places worth stopping for.",
            context: context
        )

        let coastGroup = fetchOrCreateGroup(
            named: "Coastal Favorites",
            description: "Favorite places along the Southern California coast.",
            context: context
        )


        // MARK: - Breadcrumbs

        createBreadcrumb(
            name: "Swami's Beach",
            latitude: 33.0346,
            longitude: -117.2922,
            streetAddress: "1298 S Coast Hwy 101",
            city: "Encinitas",
            state: "CA",
            zipCode: "92024",
            note: "Great overlook and one of my favorite places to stop along the coast.",
            favorite: true,
            wantToGo: false,
            daysAgo: 1,
            group: surfGroup,
            photoName: "swamis",
            context: context
        )

        createBreadcrumb(
            name: "Oceanside Harbor",
            latitude: 33.2037,
            longitude: -117.3907,
            streetAddress: "1540 Harbor Dr N",
            city: "Oceanside",
            state: "CA",
            zipCode: "92054",
            note: "Harbor walk, restaurants and a great place to watch the sunset.",
            favorite: true,
            wantToGo: false,
            daysAgo: 3,
            group: coastGroup,
            photoName: "oceanside_harbor",
            context: context
        )

        createBreadcrumb(
            name: "Torrey Pines Trail",
            latitude: 32.9210,
            longitude: -117.2526,
            streetAddress: "12600 N Torrey Pines Rd",
            city: "La Jolla",
            state: "CA",
            zipCode: "92037",
            note: "Coastal hiking with great views above the Pacific.",
            favorite: true,
            wantToGo: false,
            daysAgo: 5,
            group: outdoorsGroup,
            photoName: "torrey_pines",
            context: context
        )

        createBreadcrumb(
            name: "La Jolla Cove",
            latitude: 32.8507,
            longitude: -117.2726,
            streetAddress: "1100 Coast Blvd",
            city: "La Jolla",
            state: "CA",
            zipCode: "92037",
            note: "Good place to walk, explore the coast and spend an afternoon.",
            favorite: true,
            wantToGo: false,
            daysAgo: 7,
            group: coastGroup,
            photoName: "la_jolla_cove",
            context: context
        )

        createBreadcrumb(
            name: "Palomar Mountain",
            latitude: 33.3483,
            longitude: -116.8648,
            streetAddress: nil,
            city: "Palomar Mountain",
            state: "CA",
            zipCode: "92060",
            note: "Mountain roads, forests and plenty of places worth exploring.",
            favorite: false,
            wantToGo: true,
            daysAgo: 9,
            group: outdoorsGroup,
            photoName: "palomar",
            context: context
        )

        createBreadcrumb(
            name: "Julian Pie Company",
            latitude: 33.0786,
            longitude: -116.6027,
            streetAddress: "2225 Main St",
            city: "Julian",
            state: "CA",
            zipCode: "92036",
            note: "Save this for the next trip through Julian.",
            favorite: false,
            wantToGo: true,
            daysAgo: 12,
            group: foodGroup,
            photoName: "julian",
            context: context
        )

        createBreadcrumb(
            name: "Carlsbad Village",
            latitude: 33.1581,
            longitude: -117.3506,
            streetAddress: "State St",
            city: "Carlsbad",
            state: "CA",
            zipCode: "92008",
            note: "Restaurants, shops and an easy walk to the beach.",
            favorite: false,
            wantToGo: false,
            daysAgo: 14,
            group: coastGroup,
            photoName: "carlsbad_village",
            context: context
        )

        createBreadcrumb(
            name: "San Elijo Lagoon",
            latitude: 33.0092,
            longitude: -117.2632,
            streetAddress: "2710 Manchester Ave",
            city: "Cardiff-by-the-Sea",
            state: "CA",
            zipCode: "92007",
            note: "A good trail stop when exploring the coast.",
            favorite: false,
            wantToGo: true,
            daysAgo: 17,
            group: outdoorsGroup,
            photoName: "san_elijo_lagoon",
            context: context
        )

        createBreadcrumb(
            name: "Moonlight Beach",
            latitude: 33.0476,
            longitude: -117.2974,
            streetAddress: "400 B St",
            city: "Encinitas",
            state: "CA",
            zipCode: "92024",
            note: "Easy beach access and a good place to spend an afternoon.",
            favorite: true,
            wantToGo: false,
            daysAgo: 20,
            group: surfGroup,
            photoName: "moonlight",
            context: context
        )

        createBreadcrumb(
            name: "Mount Soledad",
            latitude: 32.8398,
            longitude: -117.2523,
            streetAddress: "6905 La Jolla Scenic Dr S",
            city: "La Jolla",
            state: "CA",
            zipCode: "92037",
            note: "Panoramic views across San Diego and the coastline.",
            favorite: false,
            wantToGo: true,
            daysAgo: 24,
            group: outdoorsGroup,
            photoName: "mount_soledad",
            context: context
        )

        createBreadcrumb(
            name: "South Ponto Beach",
            latitude: 33.0915,
            longitude: -117.3159,
            streetAddress: "Carlsbad Blvd",
            city: "Carlsbad",
            state: "CA",
            zipCode: "92011",
            note: "Good beach access and another place worth remembering.",
            favorite: false,
            wantToGo: false,
            daysAgo: 27,
            group: surfGroup,
            photoName: "south_ponto",
            context: context
        )

        do {
            try context.save()
            print("✅ Marketing demo data loaded successfully.")
        } catch {
            print("🔴 Failed to save marketing demo data: \(error)")
        }
    }


    static func delete(context: NSManagedObjectContext) {

        print("🟠 Removing marketing demo data...")

        let breadcrumbRequest: NSFetchRequest<Breadcrumb> =
            Breadcrumb.fetchRequest()

        breadcrumbRequest.predicate = NSPredicate(
            format: "name IN %@",
            demoBreadcrumbNames
        )

        do {

            let breadcrumbs = try context.fetch(breadcrumbRequest)

            for breadcrumb in breadcrumbs {
                context.delete(breadcrumb)
            }

            let groupRequest: NSFetchRequest<CrmGroup> =
                CrmGroup.fetchRequest()

            groupRequest.predicate = NSPredicate(
                format: "groupName IN %@",
                demoGroupNames
            )

            let groups = try context.fetch(groupRequest)

            for group in groups {
                context.delete(group)
            }

            try context.save()

            print("✅ Marketing demo data removed.")

        } catch {

            print(
                "🔴 Failed to delete marketing demo data: \(error)"
            )
        }
    }


    // MARK: - Breadcrumb Creation

    private static func createBreadcrumb(
        name: String,
        latitude: Double,
        longitude: Double,
        streetAddress: String?,
        city: String,
        state: String,
        zipCode: String,
        note: String,
        favorite: Bool,
        wantToGo: Bool,
        daysAgo: Int,
        group: CrmGroup,
        photoName: String?,
        context: NSManagedObjectContext
    ) {

        let breadcrumb = Breadcrumb(context: context)

        breadcrumb.id = UUID()

        breadcrumb.name = name

        breadcrumb.latitude = latitude
        breadcrumb.longitude = longitude

        breadcrumb.streetAddress = streetAddress
        breadcrumb.city = city
        breadcrumb.state = state
        breadcrumb.zipCode = zipCode

        breadcrumb.note = note

        breadcrumb.isFavorite = favorite
        breadcrumb.isWantToGo = wantToGo

        breadcrumb.dateDropped =
            Calendar.current.date(
                byAdding: .day,
                value: -daysAgo,
                to: Date()
            )

        breadcrumb.crmGroup = group

        if let photoName {

            breadcrumb.photoURL =
                installDemoPhoto(named: photoName)

        } else {

            breadcrumb.photoURL = nil
        }
    }
    
//    private static let demoPhotoNames = [
//        "swamis",
//        "oceanside_harbor",
//        "torrey_pines",
//        "la_jolla_cove",
//        "palomar",
//        "julian",
//        "moonlight",
//        "carlsbad_village",
//        "san_elijo_lagoon",
//        "mount_soledad",
//        "south_ponto"
//    ]

    private static func installDemoPhoto(
        named name: String
    ) -> String? {

        guard let sourceURL =
            Bundle.main.url(
                forResource: name,
                withExtension: "png"
            )
        else {

            print(
                "🟡 Could not find bundled demo photo: \(name).png"
            )

            return nil
        }

        guard let image =
            UIImage(contentsOfFile: sourceURL.path)
        else {

            print(
                "🔴 Could not load demo image: \(name).png"
            )

            return nil
        }

        guard let documentsURL =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {

            return nil
        }

        let fileName =
            "marketing_\(name).jpg"

        let destinationURL =
            documentsURL.appendingPathComponent(
                fileName
            )

        // If it already exists, just reuse it.
        if FileManager.default.fileExists(
            atPath: destinationURL.path
        ) {

            return fileName
        }

        guard let imageData =
            image.jpegData(
                compressionQuality: 0.8
            )
        else {

            print(
                "🔴 Could not convert \(name) to JPEG."
            )

            return nil
        }

        do {

            try imageData.write(
                to: destinationURL
            )

            print(
                "📸 Installed demo photo: \(fileName)"
            )

            return fileName

        } catch {

            print(
                "🔴 Failed saving demo photo \(name): \(error)"
            )

            return nil
        }
    }
    
    
    // MARK: - Group Creation

    private static func fetchOrCreateGroup(
        named name: String,
        description: String,
        context: NSManagedObjectContext
    ) -> CrmGroup {

        let request: NSFetchRequest<CrmGroup> =
            CrmGroup.fetchRequest()

        request.fetchLimit = 1

        request.predicate = NSPredicate(
            format: "groupName == %@",
            name
        )

        if let existing =
            try? context.fetch(request).first {

            return existing
        }

        let group = CrmGroup(context: context)

        group.id = UUID()
        group.groupName = name
        group.groupDescription = description
        group.dateCreated = Date()

        return group
    }


    // MARK: - Existing Data Check

    private static func marketingDataExists(
        context: NSManagedObjectContext
    ) -> Bool {

        let request: NSFetchRequest<Breadcrumb> =
            Breadcrumb.fetchRequest()

        request.fetchLimit = 1

        request.predicate = NSPredicate(
            format: "name IN %@",
            demoBreadcrumbNames
        )

        do {

            return try context.count(
                for: request
            ) > 0

        } catch {

            print(
                "🔴 Error checking marketing data: \(error)"
            )

            return false
        }
    }


    // MARK: - Demo Data Identifiers

    private static let demoBreadcrumbNames: [String] = [

        "Swami's Beach",
        "Oceanside Harbor",
        "Torrey Pines Trail",
        "La Jolla Cove",
        "Palomar Mountain",
        "Julian Pie Company",
        "Carlsbad Village",
        "San Elijo Lagoon",
        "Moonlight Beach",
        "Mount Soledad",
        "South Ponto Beach"

    ]


    private static let demoGroupNames: [String] = [

        "Surf Spots",
        "Outdoor Adventures",
        "Food & Stops",
        "Coastal Favorites"

    ]
}

#endif
