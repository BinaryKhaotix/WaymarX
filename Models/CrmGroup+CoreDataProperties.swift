//
//  CrmGroup+CoreDataProperties.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/26/25.
//
//

import Foundation
import CoreData


extension CrmGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CrmGroup> {
        return NSFetchRequest<CrmGroup>(entityName: "CrmGroup")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var dateCreated: Date?
    @NSManaged public var groupDescription: String?
    @NSManaged public var groupName: String?
    @NSManaged public var breadcrumbs: NSSet?

}

// MARK: Generated accessors for breadcrumbs
extension CrmGroup {

    @objc(addBreadcrumbsObject:)
    @NSManaged public func addToBreadcrumbs(_ value: Breadcrumb)

    @objc(removeBreadcrumbsObject:)
    @NSManaged public func removeFromBreadcrumbs(_ value: Breadcrumb)

    @objc(addBreadcrumbs:)
    @NSManaged public func addToBreadcrumbs(_ values: NSSet)

    @objc(removeBreadcrumbs:)
    @NSManaged public func removeFromBreadcrumbs(_ values: NSSet)
    
    var breadcrumbsArray: [Breadcrumb] {
        // Convert NSSet to [Breadcrumb], sorted by dateDropped
        (breadcrumbs as? Set<Breadcrumb>)?.sorted {
            ($0.dateDropped ?? Date.distantPast) < ($1.dateDropped ?? Date.distantPast)
        } ?? []
    }


}

extension CrmGroup : Identifiable {

}
