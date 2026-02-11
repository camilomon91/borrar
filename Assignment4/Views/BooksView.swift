import SwiftUI
import CoreData

struct BooksView: View {
    @EnvironmentObject var holder: LibraryHolder

    @State private var searchText = ""
    @State private var selectedCategoryID: NSManagedObjectID?
    @State private var showingAddSheet = false
    @State private var editingBook: Book?

    private var filteredBooks: [Book] {
        holder.books.filter { book in
            let matchesCategory: Bool
            if let selectedCategoryID {
                matchesCategory = book.category?.objectID == selectedCategoryID
            } else {
                matchesCategory = true
            }

            if searchText.isEmpty {
                return matchesCategory
            }

            let query = searchText.lowercased()
            let title = (book.title ?? "").lowercased()
            let author = (book.author ?? "").lowercased()
            return matchesCategory && (title.contains(query) || author.contains(query))
        }
    }

    var body: some View {
        Group {
            if holder.books.isEmpty {
                ContentUnavailableView("No Books Yet", systemImage: "books.vertical", description: Text("Add your first book to start borrowing."))
            } else {
                List {
                    ForEach(filteredBooks, id: \.objectID) { book in
                        Button {
                            editingBook = book
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title ?? "Untitled")
                                    .font(.headline)
                                Text("\(book.author ?? "Unknown") • \(book.category?.name ?? "No Category")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(book.isAvailable ? "Available" : "Unavailable")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(book.isAvailable ? .green : .red)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            holder.deleteBook(book: filteredBooks[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Books")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Book", systemImage: "plus")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search by title or author")
        .safeAreaInset(edge: .top) {
            Picker("Category", selection: $selectedCategoryID) {
                Text("All").tag(NSManagedObjectID?.none)
                ForEach(holder.categories, id: \.objectID) { category in
                    Text(category.name ?? "Unnamed")
                        .tag(Optional(category.objectID))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingAddSheet) {
            BookFormView(mode: .add)
                .environmentObject(holder)
        }
        .sheet(item: $editingBook) { book in
            BookFormView(mode: .edit(book))
                .environmentObject(holder)
        }
        .onAppear {
            holder.refreshBooks()
            holder.refreshCategories()
        }
    }
}

private struct BookFormView: View {
    enum Mode {
        case add
        case edit(Book)
    }

    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    @State private var selectedCategoryID: NSManagedObjectID?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("ISBN (optional)", text: $isbn)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("None").tag(NSManagedObjectID?.none)
                        ForEach(holder.categories, id: \.objectID) { category in
                            Text(category.name ?? "Unnamed")
                                .tag(Optional(category.objectID))
                        }
                    }
                }
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if case .edit(let book) = mode {
                    title = book.title ?? ""
                    author = book.author ?? ""
                    isbn = book.isbn ?? ""
                    selectedCategoryID = book.category?.objectID
                }
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "Add Book"
        case .edit: return "Edit Book"
        }
    }

    private func save() {
        let category = holder.categories.first { $0.objectID == selectedCategoryID }

        switch mode {
        case .add:
            holder.createBook(title: title, author: author, isbn: isbn, category: category)
        case .edit(let book):
            holder.updateBook(book: book, title: title, author: author, isbn: isbn, category: category)
        }
    }
}

#Preview {
    NavigationStack {
        BooksView()
    }
}
