//
//  WaymarXBackup.swift.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/21/26.
//

import Foundation

// MARK: - Complete WaymarX Backup

struct WaymarXBackup: Codable {

    let backupFormatVersion: Int
    let createdAt: Date

    let appVersion: String
    let buildNumber: String

    let users: [WaymarXUserBackup]
    let groups: [WaymarXGroupBackup]
    let breadcrumbs: [WaymarXBreadcrumbBackup]
}


// MARK: - User / Profile Backup

struct WaymarXUserBackup: Codable {

    let username: String?
    let name: String?

    let address: String?
    let phoneNumber: String?

    let homeLatitude: Double
    let homeLongitude: Double

    let profilePicture: Data?

    // Password intentionally excluded from backup.
}


// MARK: - Group Backup

struct WaymarXGroupBackup: Codable {

    let id: UUID

    let dateCreated: Date?
    let groupDescription: String?
    let groupName: String?
}


// MARK: - Breadcrumb Backup

struct WaymarXBreadcrumbBackup: Codable {

    // Breadcrumb currently has no UUID in Core Data,
    // so this ID exists only inside the backup.
    let backupID: UUID

    let dateDropped: Date?

    let latitude: Double
    let longitude: Double

    let name: String?
    let note: String?

    let isFavorite: Bool

    let streetAddress: String?
    let city: String?
    let state: String?
    let zipCode: String?

    // Existing photo filename/reference.
    // Actual photo files will be packaged later.
    let photoURL: String?

    // Relationship information
    let groupID: UUID?
    let groupName: String?
    let isWantToGo: Bool
    let wantToGoDate: Date?
    let visitedDate: Date?
    let arrivalRadius: Double?
}
