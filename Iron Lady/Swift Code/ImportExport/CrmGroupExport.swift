//
//  CrmGroupExport.swift
//  Iron Lady
//
//  Created by Dino Grillo on 3/19/25.
//

import Foundation

struct CrmGroupExport: Codable {
    let id: UUID
    let groupName: String?
    let groupDescription: String?
    let dateCreated: Date?
    let breadcrumbs: [BreadcrumbExport]
}
