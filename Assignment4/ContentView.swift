import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                BooksView()
            }
            .tabItem {
                Label("Books", systemImage: "books.vertical")
            }

            NavigationStack {
                MembersView()
            }
            .tabItem {
                Label("Members", systemImage: "person.2")
            }

            NavigationStack {
                CategoriesView()
            }
            .tabItem {
                Label("Categories", systemImage: "folder")
            }

            NavigationStack {
                LoansView()
            }
            .tabItem {
                Label("Loans", systemImage: "clock.badge.checkmark")
            }
        }
    }
}

#Preview {
    ContentView()
}
