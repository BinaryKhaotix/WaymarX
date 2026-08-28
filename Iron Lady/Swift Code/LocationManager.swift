//
//  LocationManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var streetAddress: String = "No Address"
    @Published var city: String = "No City"
    @Published var state: String = "No State"
    @Published var zipCode: String = "No Zip"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation() // ✅ Start tracking immediately
    }

    func startUpdates() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdates() {
        locationManager.stopUpdatingLocation()
    }

    func requestLocation() {
        locationManager.requestLocation()
    }

    func reverseGeocode(location: CLLocation, completion: @escaping (CLPlacemark?) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            completion(placemarks?.first)
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.currentLocation = location.coordinate
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to fetch location: \(error.localizedDescription)")
    }
}

// DMG - 07282025
//import CoreLocation
//import SwiftUI
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private let locationManager = CLLocationManager()
//    private let geocoder = CLGeocoder()
//
//    @Published var currentLocation: CLLocationCoordinate2D?
//    @Published var streetAddress: String = "No Address"
//    @Published var city: String = "No City"
//    @Published var state: String = "No State"
//    @Published var zipCode: String = "No Zip"
//
//    override init() {
//        super.init()
//        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // High accuracy
//        locationManager.distanceFilter = 10 // Only update for significant location changes
//        locationManager.requestWhenInUseAuthorization()
//    }
//
//    func requestLocation() {
//        locationManager.requestLocation()
//    }
//
//    // Public method for reverse geocoding
//    func reverseGeocode(location: CLLocation, completion: @escaping (CLPlacemark?) -> Void) {
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//
//            if let placemark = placemarks?.first {
//                completion(placemark)
//            } else {
//                print("No placemarks found.")
//                completion(nil)
//            }
//        }
//    }
//
//    // CLLocationManagerDelegate Methods
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.first {
//            DispatchQueue.main.async {
//                self.currentLocation = location.coordinate
//            }
//        }
//    }
//
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Failed to fetch location: \(error.localizedDescription)")
//    }
//}

//import CoreLocation
//import SwiftUI
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private let locationManager = CLLocationManager()
//    private let geocoder = CLGeocoder()
//
//    @Published var currentLocation: CLLocationCoordinate2D?
//    @Published var streetAddress: String = "No Address"
//    @Published var city: String = "No City"
//    @Published var state: String = "No State"
//    @Published var zipCode: String = "No Zip"
//
//    override init() {
//        super.init()
//        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // High accuracy
//        locationManager.distanceFilter = 10 // Only update for significant location changes
//        locationManager.requestWhenInUseAuthorization()
//    }
//
//    func requestLocation() {
//        locationManager.requestLocation()
//    }
//
//    // CLLocationManagerDelegate Methods
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.first {
//            DispatchQueue.main.async {
//                self.currentLocation = location.coordinate
//                self.reverseGeocode(location: location)
//            }
//        }
//    }
//
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Failed to fetch location: \(error.localizedDescription)")
//    }
//
//    private func reverseGeocode(location: CLLocation) {
//        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
//            guard let self = self else { return }
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                self.streetAddress = "Unavailable"
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//                return
//            }
//
//            if let placemark = placemarks?.first {
//                DispatchQueue.main.async {
//                    self.streetAddress = [
//                        placemark.subThoroughfare ?? "", // Street number
//                        placemark.thoroughfare ?? ""    // Street name
//                    ]
//                    .filter { !$0.isEmpty } // Remove empty components
//                    .joined(separator: " ") // Join with a space
//
//                    self.city = placemark.locality ?? "No City"
//                    self.state = placemark.administrativeArea ?? "No State"
//                    self.zipCode = placemark.postalCode ?? "No Zip"
//                }
//            } else {
//                print("No placemarks found.")
//                self.streetAddress = "Unavailable"
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//            }
//        }
//    }
//}


//import CoreLocation
//import SwiftUI
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private let locationManager = CLLocationManager()
//    private let geocoder = CLGeocoder()
//
//    @Published var currentLocation: CLLocationCoordinate2D?
//    @Published var city: String = "No City"
//    @Published var state: String = "No State"
//    @Published var zipCode: String = "No Zip"
//    @Published var streetAddress: String = "No Address" // New property for the street address
//
//    override init() {
//        super.init()
//        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // High accuracy
//        locationManager.distanceFilter = 10 // Only update for significant location changes
//        locationManager.requestWhenInUseAuthorization()
//    }
//
//    func requestLocation() {
//        locationManager.requestLocation()
//    }
//
//    // CLLocationManagerDelegate Methods
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.first {
//            DispatchQueue.main.async {
//                self.currentLocation = location.coordinate
//                self.reverseGeocode(location: location)
//            }
//        }
//    }
//
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Failed to fetch location: \(error.localizedDescription)")
//    }
//
//    private func reverseGeocode(location: CLLocation) {
//        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
//            guard let self = self else { return }
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//                self.streetAddress = "Unavailable"
//                return
//            }
//
//            if let placemark = placemarks?.first {
//                DispatchQueue.main.async {
//                    self.city = placemark.locality ?? "No City"
//                    self.state = placemark.administrativeArea ?? "No State"
//                    self.zipCode = placemark.postalCode ?? "No Zip"
//                    self.streetAddress = placemark.thoroughfare ?? "No Address" // Get the street address
//                }
//            } else {
//                print("No placemarks found.")
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//                self.streetAddress = "Unavailable"
//            }
//        }
//    }
//}


//import CoreLocation
//import SwiftUI
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private let locationManager = CLLocationManager()
//    private let geocoder = CLGeocoder()
//
//    @Published var currentLocation: CLLocationCoordinate2D?
//    @Published var city: String = "No City"
//    @Published var state: String = "No State"
//    @Published var zipCode: String = "No Zip"
//
//    override init() {
//        super.init()
//        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // High accuracy
//        locationManager.distanceFilter = 10 // Only update for significant location changes
//        locationManager.requestWhenInUseAuthorization()
//    }
//
//    func requestLocation() {
//        locationManager.requestLocation()
//    }
//
//    // CLLocationManagerDelegate Methods
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.first {
//            DispatchQueue.main.async {
//                self.currentLocation = location.coordinate
//                self.reverseGeocode(location: location)
//            }
//        }
//    }
//
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Failed to fetch location: \(error.localizedDescription)")
//    }
//
//    private func reverseGeocode(location: CLLocation) {
//        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
//            guard let self = self else { return }
//            if let error = error {
//                print("Reverse geocoding failed: \(error.localizedDescription)")
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//                return
//            }
//
//            if let placemark = placemarks?.first {
//                DispatchQueue.main.async {
//                    self.city = placemark.locality ?? "No City"
//                    self.state = placemark.administrativeArea ?? "No State"
//                    self.zipCode = placemark.postalCode ?? "No Zip"
//                }
//            } else {
//                print("No placemarks found.")
//                self.city = "Unavailable"
//                self.state = "Unavailable"
//                self.zipCode = "Unavailable"
//            }
//        }
//    }
//}




//import CoreLocation
//import SwiftUI
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private let locationManager = CLLocationManager()
//    @Published var currentLocation: CLLocationCoordinate2D?
//
//    override init() {
//        super.init()
//        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyBest
//        locationManager.requestWhenInUseAuthorization()
//    }
//
//    func requestLocation() {
//        locationManager.requestLocation()
//    }
//
//    // CLLocationManagerDelegate Methods
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.first {
//            DispatchQueue.main.async {
//                self.currentLocation = location.coordinate
//            }
//        }
//    }
//
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Failed to fetch location: \(error.localizedDescription)")
//    }
//}
