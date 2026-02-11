import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var holder: LibraryHolder

    @State private var showingAddCategory = false
    @State private var editingCategory: Category?

    var body: some View {
        List {
            if holder.categories.isEmpty {
                Text("No categories yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(holder.categories, id: \.objectID) { category in
                    Button(category.name ?? "Unnamed") {
                        editingCategory = category
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        holder.deleteCategory(category: holder.categories[index])
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    showingAddCategory = true
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            CategoryFormView(mode: .add)
                .environmentObject(holder)
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(mode: .edit(category))
                .environmentObject(holder)
        }
        .onAppear {
            holder.refreshCategories()
        }
    }
}

private struct CategoryFormView: View {
    enum Mode {
        case add
        case edit(Category)
    }

    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @State private var name = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $name)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
                if case .edit(let category) = mode {
                    name = category.name ?? ""
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .add:
            return "Add Category"
        case .edit:
            return "Edit Category"
        }
    }

    private func save() {
        switch mode {
        case .add:
            holder.createCategory(name: name)
        case .edit(let category):
            holder.updateCategory(category: category, name: name)
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
}
