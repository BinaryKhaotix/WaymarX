//
//  Breadcrumb+CoreDataProperties.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/13/24.
//
//

import Foundation
import CoreData


extension Breadcrumb {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Breadcrumb> {
        return NSFetchRequest<Breadcrumb>(entityName: "Breadcrumb")
    }

    @NSManaged public var dateDropped: Date?
    @NSManaged public var groupName: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var name: String?
    @NSManaged public var note: String?
    @NSManaged public var photoURL: String?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var streetAddress: String?
    @NSManaged public var city: String?
    @NSManaged public var state: String?
    @NSManaged public var zipCode: String?
}

extension Breadcrumb : Identifiable {

}
