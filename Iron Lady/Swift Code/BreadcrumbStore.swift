//
//  BreadcrumbStore.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/15/26.
//

import Foundation
import Combine

final class BreadcrumbStore: ObservableObject {

    @Published var breadcrumbs: [Breadcrumb] = []

    var favorites: [Breadcrumb] {
        breadcrumbs
            .filter { $0.isFavorite }
//            .sorted { $0.date > $1.date }
    }
}
