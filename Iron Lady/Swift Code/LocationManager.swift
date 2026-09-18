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
    
    private var locationCompletion: ((CLLocation?) -> Void)?
    private var manualRefreshInProgress = false
    
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
        
        print("🔵 LocationManager.requestLocation() CALLED")
        print("🔵 Authorization: \(locationManager.authorizationStatus.rawValue)")
        

        locationManager.requestLocation()
    }
    
    func requestLocation(
        completion: @escaping (CLLocation?) -> Void
    ) {
        locationCompletion = completion
        locationManager.requestLocation()
    }
    
    func refreshLocation() {

        print("🔵 refreshLocation() CALLED")

        locationManager.stopUpdatingLocation()
        
        manualRefreshInProgress = true

        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

        locationManager.startUpdatingLocation()
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
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard let location = locations.last else {
            return
        }

        print("🟢 didUpdateLocations CALLED: \(Date())")

        print("""
        📍 Fresh Location
        Latitude: \(location.coordinate.latitude)
        Longitude: \(location.coordinate.longitude)
        Accuracy: \(location.horizontalAccuracy)
        Timestamp: \(location.timestamp)
        """)

        DispatchQueue.main.async {

            self.currentLocation = location.coordinate

            self.locationCompletion?(location)
            self.locationCompletion = nil

            DiagnosticsStore.shared.updateLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy
            )
            
            if self.manualRefreshInProgress {

                self.manualRefreshInProgress = false

                // Restore normal operating behavior
                self.locationManager.distanceFilter = 10

                print("🛑 Manual location refresh complete")
            }

        }
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        
        print(
            "Location request failed: \(error.localizedDescription)"
        )
        
        locationCompletion?(nil)
        locationCompletion = nil
    }
}
