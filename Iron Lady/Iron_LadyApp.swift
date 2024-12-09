//
//  Iron_LadyApp.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//

import SwiftUI

@main
struct Iron_LadyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
