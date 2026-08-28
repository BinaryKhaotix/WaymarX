//
//  AddressUpdater.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/23/25.
//

import CoreData
import CoreLocation

class AddressUpdater {
    private let viewContext: NSManagedObjectContext
    private let locationManager: LocationManager

    init(viewContext: NSManagedObjectContext, locationManager: LocationManager) {
        self.viewContext = viewContext
        self.locationManager = locationManager
    }

    func updateMissingAddressesAndIDs(
        onProgressUpdate: @escaping (Double) -> Void,
        onCompletion: @escaping () -> Void
    ) {
        // Existing address update logic...
        onCompletion()
    }

    func migrateGroupNamesToCrmGroup(onCompletion: @escaping () -> Void) {
        let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()

        do {
            let breadcrumbs = try viewContext.fetch(fetchRequest)

            // Extract unique group names from breadcrumbs
            let uniqueGroupNames = Set(breadcrumbs.compactMap { $0.crmGroup?.groupName })

            for groupName in uniqueGroupNames {
                // Create a new CrmGroup for each unique group name
                let newGroup = CrmGroup(context: viewContext)
                newGroup.id = UUID()
                newGroup.dateCreated = Date()
                newGroup.groupName = groupName // Assign the group name
                newGroup.groupDescription = "Migrated from Breadcrumbs"
            }

            // Save the context if there are changes
            if viewContext.hasChanges {
                try viewContext.save()
                print("Successfully migrated \(uniqueGroupNames.count) group names to CrmGroup.")
            }
        } catch {
            print("Failed to fetch Breadcrumbs or migrate group names: \(error)")
        }

        // Call the completion handler
        onCompletion()
    }
}



//import CoreData
//import CoreLocation
//
//
//class AddressUpdater {
//    private let viewContext: NSManagedObjectContext
//    private let locationManager: LocationManager
//
//    init(viewContext: NSManagedObjectContext, locationManager: LocationManager) {
//        self.viewContext = viewContext
//        self.locationManager = locationManager
//    }
//
//    func updateMissingAddressesAndIDs(
//        onProgressUpdate: @escaping (Double) -> Void,
//        onCompletion: @escaping () -> Void
//    ) {
//        let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
//
//        do {
//            let breadcrumbs = try viewContext.fetch(fetchRequest)
//            let totalCount = breadcrumbs.count
//            var updatedCount = 0
//
//            for breadcrumb in breadcrumbs {
//                // Check for missing address information
//                if breadcrumb.city == nil || breadcrumb.streetAddress == nil {
//                    // Update address logic
//                    updateAddress(for: breadcrumb)
//                }
//
//                // Check for missing IDs and assign a new UUID if necessary
//                if breadcrumb.id == nil {
//                    breadcrumb.id = UUID()
//                }
//
//                updatedCount += 1
//                let progress = Double(updatedCount) / Double(totalCount)
//                onProgressUpdate(progress)
//            }
//
//            // Save changes to Core Data
//            if viewContext.hasChanges {
//                try viewContext.save()
//            }
//
//            onCompletion()
//        } catch {
//            print("Error updating breadcrumbs: \(error)")
//            onCompletion()
//        }
//    }
//
//    private func updateAddress(for breadcrumb: Breadcrumb) {
//        // Address update logic (e.g., reverse geocoding using `locationManager`)
//        // Example:
//        breadcrumb.city = "Sample City"
//        breadcrumb.streetAddress = "Sample Street"
//    }
//}


//import CoreData
//import CoreLocation
//
//class AddressUpdater {
//    private let geocoder = CLGeocoder()
//    private let viewContext: NSManagedObjectContext
//    private let locationManager: LocationManager
//    private let requestInterval: TimeInterval = 2.0
//    private let maxRetries = 3
//
//    init(viewContext: NSManagedObjectContext, locationManager: LocationManager) {
//        self.viewContext = viewContext
//        self.locationManager = locationManager
//    }
//
//    func updateMissingAddresses(
//        onProgressUpdate: @escaping (Double) -> Void,
//        onCompletion: @escaping () -> Void
//    ) {
//        // Check if the update has already been performed
//        guard !UserDefaults.standard.didPerformAddressUpdate else {
//            print("Address update has already been performed. Skipping...")
//            DispatchQueue.main.async {
//                onCompletion() // Ensure UI state is updated when skipping
//            }
//            return
//        }
//
//        DispatchQueue.global(qos: .background).async {
//            let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
//            do {
//                // Fetch breadcrumbs
//                let breadcrumbs = try self.viewContext.fetch(fetchRequest)
//                print("Fetched \(breadcrumbs.count) breadcrumbs from Core Data.")
//
//                // Filter breadcrumbs requiring updates
//                let breadcrumbsToUpdate = breadcrumbs.filter {
//                    $0.streetAddress == nil || $0.city == nil || $0.state == nil || $0.zipCode == nil
//                }
//                print("\(breadcrumbsToUpdate.count) breadcrumbs require address updates.")
//
//                // Handle case where no updates are needed
//                guard !breadcrumbsToUpdate.isEmpty else {
//                    DispatchQueue.main.async {
//                        UserDefaults.standard.didPerformAddressUpdate = true
//                        onCompletion()
//                    }
//                    return
//                }
//
//                let totalCount = breadcrumbsToUpdate.count
//                var processedCount = 0
//
//                for (index, breadcrumb) in breadcrumbsToUpdate.enumerated() {
//                    Thread.sleep(forTimeInterval: self.requestInterval)
//
//                    print("Processing breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//
//                    self.reverseGeocodeWithRetry(location: CLLocation(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude), retryCount: 0) { placemark in
//                        if let placemark = placemark {
//                            breadcrumb.streetAddress = [
//                                placemark.subThoroughfare ?? "",
//                                placemark.thoroughfare ?? ""
//                            ].filter { !$0.isEmpty }.joined(separator: " ")
//                            breadcrumb.city = placemark.locality ?? "No City"
//                            breadcrumb.state = placemark.administrativeArea ?? "No State"
//                            breadcrumb.zipCode = placemark.postalCode ?? "No Zip"
//                            
//                            print("Updated address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        } else {
//                            print("Failed to get address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        }
//
//                        processedCount += 1
//
//                        DispatchQueue.main.async {
//                            onProgressUpdate(Double(processedCount) / Double(totalCount))
//                        }
//
//                        // Save every 10 records or at the end
//                        if index % 10 == 0 || processedCount == totalCount {
//                            DispatchQueue.main.async {
//                                do {
//                                    try self.viewContext.save()
//                                    print("Saved updated breadcrumbs to Core Data.")
//                                } catch {
//                                    print("Failed to save updated address: \(error.localizedDescription)")
//                                }
//                            }
//                        }
//
//                        // Call completion handler when finished
//                        if processedCount == totalCount {
//                            DispatchQueue.main.async {
//                                UserDefaults.standard.didPerformAddressUpdate = true
//                                onCompletion()
//                            }
//                        }
//                    }
//                }
//            } catch {
//                print("Failed to fetch breadcrumbs: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    onCompletion()
//                }
//            }
//        }
//    }
//
//    private func reverseGeocodeWithRetry(location: CLLocation, retryCount: Int, completion: @escaping (CLPlacemark?) -> Void) {
//        guard retryCount < maxRetries else {
//            print("Max retries reached for location: \(location.coordinate)")
//            completion(nil)
//            return
//        }
//
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            if let error = error {
//                print("Reverse geocoding error: \(error.localizedDescription)")
//                DispatchQueue.global().asyncAfter(deadline: .now() + self.requestInterval) {
//                    self.reverseGeocodeWithRetry(location: location, retryCount: retryCount + 1, completion: completion)
//                }
//            } else {
//                completion(placemarks?.first)
//            }
//        }
//    }
//}


//import CoreData
//import CoreLocation
//
//class AddressUpdater {
//    private let geocoder = CLGeocoder()
//    private let viewContext: NSManagedObjectContext
//    private let locationManager: LocationManager
//    private let requestInterval: TimeInterval = 2.0
//    private let maxRetries = 3
//
//    init(viewContext: NSManagedObjectContext, locationManager: LocationManager) {
//        self.viewContext = viewContext
//        self.locationManager = locationManager
//    }
//
//    func updateMissingAddresses(
//        onProgressUpdate: @escaping (Double) -> Void,
//        onCompletion: @escaping () -> Void
//    ) {
//        // Check if the update has already been performed
//        guard !UserDefaults.standard.didPerformAddressUpdate else {
//            print("Address update has already been performed. Skipping...")
//            onCompletion()
//            return
//        }
//
//        DispatchQueue.global(qos: .background).async {
//            let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
//            do {
//                // Fetch breadcrumbs
//                let breadcrumbs = try self.viewContext.fetch(fetchRequest)
//                print("Fetched \(breadcrumbs.count) breadcrumbs from Core Data.")
//
//                // Filter breadcrumbs requiring updates
//                let breadcrumbsToUpdate = breadcrumbs.filter {
//                    $0.streetAddress == nil || $0.city == nil || $0.state == nil || $0.zipCode == nil
//                }
//                print("\(breadcrumbsToUpdate.count) breadcrumbs require address updates.")
//
//                // Handle case where no updates are needed
//                guard !breadcrumbsToUpdate.isEmpty else {
//                    DispatchQueue.main.async {
//                        UserDefaults.standard.didPerformAddressUpdate = true
//                        onCompletion()
//                    }
//                    return
//                }
//
//                let totalCount = breadcrumbsToUpdate.count
//                var processedCount = 0
//
//                for (index, breadcrumb) in breadcrumbsToUpdate.enumerated() {
//                    Thread.sleep(forTimeInterval: self.requestInterval)
//
//                    print("Processing breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//
//                    self.reverseGeocodeWithRetry(location: CLLocation(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude), retryCount: 0) { placemark in
//                        if let placemark = placemark {
//                            breadcrumb.streetAddress = [
//                                placemark.subThoroughfare ?? "",
//                                placemark.thoroughfare ?? ""
//                            ].filter { !$0.isEmpty }.joined(separator: " ")
//                            breadcrumb.city = placemark.locality ?? "No City"
//                            breadcrumb.state = placemark.administrativeArea ?? "No State"
//                            breadcrumb.zipCode = placemark.postalCode ?? "No Zip"
//                            
//                            print("Updated address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        } else {
//                            print("Failed to get address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        }
//
//                        processedCount += 1
//
//                        DispatchQueue.main.async {
//                            onProgressUpdate(Double(processedCount) / Double(totalCount))
//                        }
//
//                        // Save every 10 records or at the end
//                        if index % 10 == 0 || processedCount == totalCount {
//                            DispatchQueue.main.async {
//                                do {
//                                    try self.viewContext.save()
//                                    print("Saved updated breadcrumbs to Core Data.")
//                                } catch {
//                                    print("Failed to save updated address: \(error.localizedDescription)")
//                                }
//                            }
//                        }
//
//                        // Call completion handler when finished
//                        if processedCount == totalCount {
//                            DispatchQueue.main.async {
//                                UserDefaults.standard.didPerformAddressUpdate = true
//                                onCompletion()
//                            }
//                        }
//                    }
//                }
//            } catch {
//                print("Failed to fetch breadcrumbs: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    onCompletion()
//                }
//            }
//        }
//    }

    
//    func updateMissingAddresses(
//        onProgressUpdate: @escaping (Double) -> Void,
//        onCompletion: @escaping () -> Void
//    ) {
//        // Check if the update has already been performed
//        guard !UserDefaults.standard.didPerformAddressUpdate else {
//            print("Address update has already been performed. Skipping...")
//            onCompletion()
//            return
//        }
//
//        DispatchQueue.global(qos: .background).async {
//            let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
//            do {
//                let breadcrumbs = try self.viewContext.fetch(fetchRequest)
//                let breadcrumbsToUpdate = breadcrumbs.filter {
//                    $0.streetAddress == nil || $0.city == nil || $0.state == nil || $0.zipCode == nil
//                }
//
//                let totalCount = breadcrumbsToUpdate.count
//                var processedCount = 0
//
//                for (index, breadcrumb) in breadcrumbsToUpdate.enumerated() {
//                    Thread.sleep(forTimeInterval: self.requestInterval)
//
//                    self.reverseGeocodeWithRetry(location: CLLocation(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude), retryCount: 0) { placemark in
//                        if let placemark = placemark {
//                            breadcrumb.streetAddress = [
//                                placemark.subThoroughfare ?? "",
//                                placemark.thoroughfare ?? ""
//                            ].filter { !$0.isEmpty }.joined(separator: " ")
//                            breadcrumb.city = placemark.locality ?? "No City"
//                            breadcrumb.state = placemark.administrativeArea ?? "No State"
//                            breadcrumb.zipCode = placemark.postalCode ?? "No Zip"
//                            
//                            print("Updated address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        } else {
//                            print("Failed to get address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        }
//
//                        processedCount += 1
//
//                        DispatchQueue.main.async {
//                            onProgressUpdate(Double(processedCount) / Double(totalCount))
//                        }
//
//                        if index % 10 == 0 || processedCount == totalCount {
//                            do {
//                                try self.viewContext.save()
//                            } catch {
//                                print("Failed to save updated address: \(error.localizedDescription)")
//                            }
//                        }
//
//                        if processedCount == totalCount {
//                            DispatchQueue.main.async {
//                                UserDefaults.standard.didPerformAddressUpdate = true // Mark the update as completed
//                                onCompletion()
//                            }
//                        }
//                    }
//                }
//            } catch {
//                print("Failed to fetch breadcrumbs: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    onCompletion()
//                }
//            }
//        }
//    }

//    private func reverseGeocodeWithRetry(location: CLLocation, retryCount: Int, completion: @escaping (CLPlacemark?) -> Void) {
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            if let error = error as NSError?, error.domain == kCLErrorDomain && error.code == -3, retryCount < self.maxRetries {
//                let backoffDelay = pow(2.0, Double(retryCount)) * self.requestInterval
//                print("Throttling detected. Retrying in \(backoffDelay) seconds...")
//                DispatchQueue.global().asyncAfter(deadline: .now() + backoffDelay) {
//                    self.reverseGeocodeWithRetry(location: location, retryCount: retryCount + 1, completion: completion)
//                }
//                return
//            }
//
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//
//            completion(placemarks?.first)
//        }
//    }
//}


//import CoreData
//import CoreLocation
//
//class AddressUpdater {
//    private let geocoder = CLGeocoder()
//    private let viewContext: NSManagedObjectContext
//    private let locationManager: LocationManager
//    private var updateProgressCallback: ((Double) -> Void)?
//    private var completionCallback: (() -> Void)?
//
//    // Initialize AddressUpdater with required dependencies
//    init(viewContext: NSManagedObjectContext, locationManager: LocationManager) {
//        self.viewContext = viewContext
//        self.locationManager = locationManager
//    }
//
//    func updateMissingAddresses(
//        onProgressUpdate: @escaping (Double) -> Void,
//        onCompletion: @escaping () -> Void
//    ) {
//        self.updateProgressCallback = onProgressUpdate
//        self.completionCallback = onCompletion
//
//        DispatchQueue.global(qos: .background).async {
//            let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
//            do {
//                // Fetch all breadcrumbs from Core Data
//                let breadcrumbs = try self.viewContext.fetch(fetchRequest)
//                // Filter breadcrumbs that are missing address details
//                let breadcrumbsToUpdate = breadcrumbs.filter {
//                    $0.streetAddress == nil || $0.city == nil || $0.state == nil || $0.zipCode == nil
//                }
//
//                let totalCount = breadcrumbsToUpdate.count
//                var processedCount = 0
//
//                for breadcrumb in breadcrumbsToUpdate {
//                    let location = CLLocation(latitude: breadcrumb.latitude, longitude: breadcrumb.longitude)
//
//                    let semaphore = DispatchSemaphore(value: 0) // Semaphore to manage async completion
//
//                    // Reverse geocode the location to get address details
//                    self.locationManager.reverseGeocode(location: location) { placemark in
//                        if let placemark = placemark {
//                            // Update breadcrumb with address details
//                            breadcrumb.streetAddress = [
//                                placemark.subThoroughfare ?? "",
//                                placemark.thoroughfare ?? ""
//                            ].filter { !$0.isEmpty }.joined(separator: " ")
//                            breadcrumb.city = placemark.locality ?? "No City"
//                            breadcrumb.state = placemark.administrativeArea ?? "No State"
//                            breadcrumb.zipCode = placemark.postalCode ?? "No Zip"
//                            
//                            print("Updated address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        } else {
//                            print("Failed to get address for breadcrumb: \(breadcrumb.name ?? "Unnamed")")
//                        }
//
//                        processedCount += 1
//
//                        // Update progress on the main thread
//                        DispatchQueue.main.async {
//                            self.updateProgressCallback?(Double(processedCount) / Double(totalCount))
//                        }
//
//                        semaphore.signal() // Signal completion
//                    }
//
//                    semaphore.wait() // Wait for reverse geocoding to complete
//
//                    // Save updates after each breadcrumb is processed
//                    DispatchQueue.main.async {
//                        do {
//                            try self.viewContext.save()
//                        } catch {
//                            print("Failed to save updated address: \(error.localizedDescription)")
//                        }
//                    }
//                }
//
//                // Finish the update process
//                DispatchQueue.main.async {
//                    self.completionCallback?()
//                }
//            } catch {
//                print("Failed to fetch breadcrumbs: \(error.localizedDescription)")
//            }
//        }
//    }
//}
