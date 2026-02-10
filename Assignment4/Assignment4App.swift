//
//  Assignment4App.swift
//  Assignment4
//
//  Created by Camilo Montero on 2026-02-10.
//

import SwiftUI
import CoreData

@main
struct Assignment4App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
