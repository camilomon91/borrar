import SwiftUI
import CoreData

@main
struct Assignment4App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var holder: LibraryHolder

    init() {
        let context = persistenceController.container.viewContext
        _holder = StateObject(wrappedValue: LibraryHolder(context: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(holder)
        }
    }
}
