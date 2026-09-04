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
    
    func requestLocation(
        completion: @escaping (CLLocation?) -> Void
    ) {
        locationCompletion = completion
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
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        
        guard let location = locations.last else {
            return
        }
        
        DispatchQueue.main.async {
            
            self.currentLocation = location.coordinate
            
            self.locationCompletion?(location)
            self.locationCompletion = nil
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
