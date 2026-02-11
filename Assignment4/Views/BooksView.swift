import SwiftUI
import CoreData

struct BooksView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.managedObjectContext) private var context

    @State private var showingAddSheet = false
    @State private var editingBook: Book?

    var body: some View {
        Group {
            if holder.books.isEmpty {
                ContentUnavailableView("No Books Yet", systemImage: "books.vertical")
            } else {
                List {
                    ForEach(holder.books, id: \.objectID) { book in
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
                            holder.deleteBook(holder.books[index], context)
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
        .searchable(text: Binding(
            get: { holder.searchText },
            set: { holder.setSearch($0, context) }
        ), prompt: "Search by title or author")
        .safeAreaInset(edge: .top) {
            Picker(
                "Category",
                selection: Binding(
                    get: { holder.selectedCategory?.objectID },
                    set: { newID in
                        let category = holder.categories.first { $0.objectID == newID }
                        holder.setCategory(category, context)
                    }
                )
            ) {
                Text("All").tag(NSManagedObjectID?.none)
                ForEach(holder.categories, id: \.objectID) { category in
                    Text(category.name ?? "Unnamed")
                        .tag(Optional(category.objectID))
                }
            }

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
            holder.refreshBooks(context)
            holder.refreshCategories(context)
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
    @Environment(\.managedObjectContext) private var context

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
            holder.createBook(title: title, author: author, isbn: isbn, category: category, context)
        case .edit(let book):
            holder.updateBook(book: book, title: title, author: author, isbn: isbn, category: category, context)
        }
    }
}
