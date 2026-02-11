import Foundation
import CoreData
import Combine

@MainActor
final class LibraryHolder: ObservableObject {

    // MARK: - UI State
    @Published var selectedCategory: Category? = nil
    @Published var searchText: String = ""

    // MARK: - Published Data
    @Published var categories: [Category] = []
    @Published var books: [Book] = []
    @Published var members: [Member] = []
    @Published var loans: [Loan] = []

    init(_ context: NSManagedObjectContext) {
        seedIfNeeded(context)
        refreshAll(context)
    }

    // MARK: - Refresh
    func refreshAll(_ context: NSManagedObjectContext) {
        refreshCategories(context)
        refreshBooks(context)
        refreshMembers(context)
        refreshLoans(context)
    }

    func refreshCategories(_ context: NSManagedObjectContext) {
        categories = fetchCategories(context)
    }

    func refreshBooks(_ context: NSManagedObjectContext) {
        books = fetchBooks(context)
    }

    func refreshMembers(_ context: NSManagedObjectContext) {
        members = fetchMembers(context)
    }

    func refreshLoans(_ context: NSManagedObjectContext) {
        loans = fetchLoans(context)
    }

    // MARK: - Fetchers
    func fetchCategories(_ context: NSManagedObjectContext) -> [Category] {
        do { return try context.fetch(categoriesFetch()) }
        catch { fatalError("Unresolved error \(error)") }
    }

    func fetchBooks(_ context: NSManagedObjectContext) -> [Book] {
        do { return try context.fetch(booksFetch()) }
        catch { fatalError("Unresolved error \(error)") }
    }

    func fetchMembers(_ context: NSManagedObjectContext) -> [Member] {
        do { return try context.fetch(membersFetch()) }
        catch { fatalError("Unresolved error \(error)") }
    }

    func fetchLoans(_ context: NSManagedObjectContext) -> [Loan] {
        do { return try context.fetch(loansFetch()) }
        catch { fatalError("Unresolved error \(error)") }
    }

    // MARK: - Fetch Requests
    func categoriesFetch() -> NSFetchRequest<Category> {
        let request = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        return request
    }

    func booksFetch() -> NSFetchRequest<Book> {
        let request = Book.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Book.addedAt, ascending: false),
            NSSortDescriptor(keyPath: \Book.title, ascending: true),
            NSSortDescriptor(keyPath: \Book.author, ascending: true)
        ]
        request.predicate = booksPredicate()
        return request
    }

    func membersFetch() -> NSFetchRequest<Member> {
        let request = Member.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Member.name, ascending: true)]
        return request
    }

    func loansFetch() -> NSFetchRequest<Loan> {
        let request = Loan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Loan.borrowedAt, ascending: false)]
        return request
    }

    // MARK: - Predicates (filter + search)
    private func booksPredicate() -> NSPredicate? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [NSPredicate] = []

        if let category = selectedCategory {
            parts.append(NSPredicate(format: "category == %@", category))
        }

        if !trimmed.isEmpty {
            parts.append(NSPredicate(format: "(title CONTAINS[cd] %@) OR (author CONTAINS[cd] %@)", trimmed, trimmed))
        }

        if parts.isEmpty { return nil }
        if parts.count == 1 { return parts[0] }
        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    // MARK: - Filter controls
    func setCategory(_ category: Category?, _ context: NSManagedObjectContext) {
        selectedCategory = category
        refreshBooks(context)
    }

    func setSearch(_ text: String, _ context: NSManagedObjectContext) {
        searchText = text
        refreshBooks(context)
    }

    // MARK: - Category CRUD
    func createCategory(name: String, _ context: NSManagedObjectContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let category = Category(context: context)
        category.id = UUID()
        category.name = trimmed
        saveContext(context)
    }

    func deleteCategory(_ category: Category, _ context: NSManagedObjectContext) {
        if selectedCategory == category {
            selectedCategory = nil
        }
        context.delete(category)
        saveContext(context)
    }

    // MARK: - Book CRUD
    func createBook(title: String, author: String, isbn: String?, category: Category?, _ context: NSManagedObjectContext) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanAuthor.isEmpty else { return }

        let book = Book(context: context)
        book.id = UUID()
        book.title = cleanTitle
        book.author = cleanAuthor
        book.isbn = isbn?.trimmingCharacters(in: .whitespacesAndNewlines)
        book.addedAt = Date()
        book.isAvailable = true
        book.category = category
        saveContext(context)
    }

    func updateBook(book: Book, title: String, author: String, isbn: String?, category: Category?, _ context: NSManagedObjectContext) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanAuthor.isEmpty else { return }

        book.title = cleanTitle
        book.author = cleanAuthor
        book.isbn = isbn?.trimmingCharacters(in: .whitespacesAndNewlines)
        book.category = category
        saveContext(context)
    }

    func deleteBook(_ book: Book, _ context: NSManagedObjectContext) {
        context.delete(book)
        saveContext(context)
    }

    // MARK: - Member CRUD
    func createMember(name: String, email: String, _ context: NSManagedObjectContext) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let member = Member(context: context)
        member.id = UUID()
        member.name = cleanName
        member.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        member.joinedAt = Date()
        saveContext(context)
    }

    func deleteMember(_ member: Member, _ context: NSManagedObjectContext) {
        context.delete(member)
        saveContext(context)
    }

    // MARK: - Loans
    @discardableResult
    func borrowBook(member: Member, book: Book, dueDays: Int = 7, _ context: NSManagedObjectContext) -> Bool {
        guard book.isAvailable else { return false }

        let borrowedAt = Date()
        let dueAt = Calendar.current.date(byAdding: .day, value: dueDays, to: borrowedAt) ?? borrowedAt

        let loan = Loan(context: context)
        loan.id = UUID()
        loan.member = member
        loan.book = book
        loan.borrowedAt = borrowedAt
        loan.dueAt = dueAt
        loan.returnedAt = nil
        loan.status = "Active"

        book.isAvailable = false
        saveContext(context)
        return true
    }

    func returnLoan(_ loan: Loan, _ context: NSManagedObjectContext) {
        guard loan.returnedAt == nil else { return }

        loan.returnedAt = Date()
        loan.status = "Returned"
        loan.book?.isAvailable = true
        saveContext(context)
    }


    // MARK: - Seed
    private func seedIfNeeded(_ context: NSManagedObjectContext) {
        let request = Category.fetchRequest()
        request.fetchLimit = 1

        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }

        let fiction = Category(context: context)
        fiction.id = UUID()
        fiction.name = "Fiction"

        let science = Category(context: context)
        science.id = UUID()
        science.name = "Science"

        let history = Category(context: context)
        history.id = UUID()
        history.name = "History"

        let b1 = Book(context: context)
        b1.id = UUID()
        b1.title = "The Swift Journey"
        b1.author = "Ava Cole"
        b1.isbn = "978-1-23456-001-0"
        b1.addedAt = Date()
        b1.isAvailable = true
        b1.category = science

        let b2 = Book(context: context)
        b2.id = UUID()
        b2.title = "City of Lanterns"
        b2.author = "Leo Hart"
        b2.isbn = "978-1-23456-002-7"
        b2.addedAt = Date()
        b2.isAvailable = true
        b2.category = fiction

        let b3 = Book(context: context)
        b3.id = UUID()
        b3.title = "Empire and Oceans"
        b3.author = "Mila Stone"
        b3.isbn = "978-1-23456-003-4"
        b3.addedAt = Date()
        b3.isAvailable = true
        b3.category = history

        saveContext(context)
    }

    // MARK: - Save
    func saveContext(_ context: NSManagedObjectContext) {
        do {
            try context.save()
            refreshAll(context)
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
