//
//  NavigationModel.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/27/24.
//


import SwiftUI
import CoreData

final class NavigationModel: ObservableObject {
    @Published var path: [NavigationDestination] = []

    /// Safely pop one destination (won't crash if already at root).
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Pop everything (root).
    func popToRoot() {
        path.removeAll()
    }

    /// Go directly to a known destination.
    func go(_ destination: NavigationDestination) {
        path = [destination]
    }

    /// Convenience helpers (optional but nice)
    func goToDashboard() { go(.dashboard) }
    func goToContent() { go(.content) }
}


enum NavigationDestination: Hashable {
    case addUser
    case login
    case content
    case dashboard
    case addBreadcrumb
    case addBreadcrumbToGroup(groupname: String)
    case breadcrumbDetail(breadcrumb: Breadcrumb)
    case breadcrumbDetailIDs(objectIDs: [NSManagedObjectID], startIndex: Int)
    case groupCrumbs(groupName: String)
    case groupsList
    case unnamedBreadcrumbs(breadcrumbs: [Breadcrumb])
    case allBreadcrumbs
    case breadcrumbMap(breadcrumb: Breadcrumb)
    case editBreadcrumb(breadcrumb: Breadcrumb)
    case editProfile
    case settings
    case groupCrumbMap(groupBreadcrumbs: [Breadcrumb])
    case navigateToLocation(breadcrumb: Breadcrumb)
    case favoritesBreadcrumbs
    case recentBreadcrumbs
    case wantToGoMap
    case wantToGoList
}

extension NavigationModel {
    func pushBreadcrumbDetail(in breadcrumbs: [Breadcrumb], selected breadcrumb: Breadcrumb) {
        let ids = breadcrumbs.map { $0.objectID }
        let startIndex = ids.firstIndex(of: breadcrumb.objectID) ?? 0
        path.append(.breadcrumbDetailIDs(objectIDs: ids, startIndex: startIndex))
    }
}
