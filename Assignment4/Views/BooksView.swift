import SwiftUI
import CoreData

struct BooksView: View {
    @EnvironmentObject var holder: LibraryHolder

    @State private var showingAddSheet = false
    @State private var editingBook: Book?

    var body: some View {
        VStack(spacing: 8) {
            Picker("Category", selection: Binding(
                get: { holder.selectedCategory?.objectID },
                set: { newID in
                    let category = holder.categories.first { $0.objectID == newID }
                    holder.setCategory(category)
                }
            )) {
                Text("All").tag(NSManagedObjectID?.none)
                ForEach(holder.categories, id: \.objectID) { category in
                    Text(category.name ?? "Unnamed")
                        .tag(Optional(category.objectID))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            if holder.books.isEmpty {
                Text("No Books")
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
                Spacer()
            } else {
                List {
                    ForEach(holder.books, id: \.objectID) { book in
                        Button {
                            editingBook = book
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title ?? "Untitled")
                                Text("\(book.author ?? "Unknown") • \(book.category?.name ?? "No Category")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(book.isAvailable ? "Available" : "Unavailable")
                                    .font(.caption)
                                    .foregroundStyle(book.isAvailable ? .green : .red)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            holder.deleteBook(book: holder.books[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Books")
        .searchable(text: Binding(
            get: { holder.searchText },
            set: { holder.setSearch($0) }
        ), prompt: "Search title or author")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    showingAddSheet = true
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
            holder.refreshCategories()
            holder.refreshBooks()
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
                TextField("Title", text: $title)
                TextField("Author", text: $author)
                TextField("ISBN", text: $isbn)

                Picker("Category", selection: $selectedCategoryID) {
                    Text("None").tag(NSManagedObjectID?.none)
                    ForEach(holder.categories, id: \.objectID) { category in
                        Text(category.name ?? "Unnamed")
                            .tag(Optional(category.objectID))
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
