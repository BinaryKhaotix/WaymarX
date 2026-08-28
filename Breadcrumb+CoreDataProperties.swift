//
//  Breadcrumb+CoreDataProperties.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/26/25.
//
//

import Foundation
import CoreData

extension Breadcrumb {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Breadcrumb> {
        return NSFetchRequest<Breadcrumb>(entityName: "Breadcrumb")
    }

    @NSManaged public var city: String?
    @NSManaged public var dateDropped: Date?
    @NSManaged public var wantToGoDate: Date?
    @NSManaged public var visitedDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isWantToGo: Bool
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var arrivalRadius: NSNumber?
    @NSManaged public var name: String?
    @NSManaged public var note: String?
    @NSManaged public var photoURL: String?
    @NSManaged public var state: String?
    @NSManaged public var streetAddress: String?
    @NSManaged public var zipCode: String?

    // Relationship to CrmGroup
    @NSManaged public var crmGroup: CrmGroup?
}

extension Breadcrumb: Identifiable {}
