//
//  BreadcrumbExport.swift
//  Iron Lady
//
//  Created by Dino Grillo on 3/19/25.
//

import Foundation

struct BreadcrumbExport: Codable {
    let id: UUID
    let name: String?
    let city: String?
    let state: String?
    let streetAddress: String?
    let zipCode: String?
    let dateDropped: Date?
    let latitude: Double
    let longitude: Double
    let isFavorite: Bool
    let note: String?
    let photoURL: String?
    let isWantToGo: Bool
    let wantToGoDate: Date?
    let visitedDate: Date?
    let arrivalRadius: Double?
}
