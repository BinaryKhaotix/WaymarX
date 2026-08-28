//
//  CrumbUser+CoreDataProperties.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/17/24.
//
//

import Foundation
import CoreData


extension CrumbUser {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CrumbUser> {
        return NSFetchRequest<CrumbUser>(entityName: "CrumbUser")
    }

    @NSManaged public var homeLongitude: Double
    @NSManaged public var homeLatitude: Double
    @NSManaged public var phoneNumber: String?
    @NSManaged public var address: String?
    @NSManaged public var name: String?
    @NSManaged public var profilePicture: Data?
    @NSManaged public var password: String?
    @NSManaged public var username: String?

}

extension CrumbUser : Identifiable {

}
