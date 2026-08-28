//
//  AllBreadcrumbExport.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/27/26.
//

import Foundation

struct AllBreadcrumbExport: Codable {

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
    let groupID: UUID?
    let groupName: String?
    let groupDescription: String?
    let groupDateCreated: Date?
    let isWantToGo: Bool
    let wantToGoDate: Date?
    let visitedDate: Date?
    let arrivalRadius: Double?
}
