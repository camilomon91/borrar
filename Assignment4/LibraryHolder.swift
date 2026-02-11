import Foundation
import CoreData
import Combine

@MainActor
final class LibraryHolder: ObservableObject {
    let context: NSManagedObjectContext

    @Published var selectedCategory: Category? = nil
    @Published var searchText: String = ""

    @Published var categories: [Category] = []
    @Published var books: [Book] = []
    @Published var members: [Member] = []
    @Published var loans: [Loan] = []

    init(context: NSManagedObjectContext) {
        self.context = context
        seedIfNeeded()
        refreshAll()
    }

    func refreshAll() {
        refreshCategories()
        refreshBooks()
        refreshMembers()
        refreshLoans()
    }

    func refreshCategories() {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        categories = (try? context.fetch(request)) ?? []
    }

    func refreshBooks() {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Book.title, ascending: true),
            NSSortDescriptor(keyPath: \Book.author, ascending: true)
        ]

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var predicates: [NSPredicate] = []

        if let category = selectedCategory {
            predicates.append(NSPredicate(format: "category == %@", category))
        }

        if !trimmed.isEmpty {
            predicates.append(NSPredicate(format: "(title CONTAINS[cd] %@) OR (author CONTAINS[cd] %@)", trimmed, trimmed))
        }

        if predicates.count == 1 {
            request.predicate = predicates[0]
        } else if predicates.count > 1 {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        books = (try? context.fetch(request)) ?? []
    }

    func refreshMembers() {
        let request: NSFetchRequest<Member> = Member.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Member.name, ascending: true)]
        members = (try? context.fetch(request)) ?? []
    }

    func refreshLoans() {
        let request: NSFetchRequest<Loan> = Loan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Loan.borrowedAt, ascending: false)]
        loans = (try? context.fetch(request)) ?? []
    }

    func setCategory(_ category: Category?) {
        selectedCategory = category
        refreshBooks()
    }

    func setSearch(_ text: String) {
        searchText = text
        refreshBooks()
    }

    func createCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let category = Category(context: context)
        category.id = UUID()
        category.name = trimmed
        saveContext()
    }

    func createBook(title: String, author: String, isbn: String?, category: Category?) {
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
        saveContext()
    }

    func updateBook(book: Book, title: String, author: String, isbn: String?, category: Category?) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanAuthor.isEmpty else { return }

        book.title = cleanTitle
        book.author = cleanAuthor
        book.isbn = isbn?.trimmingCharacters(in: .whitespacesAndNewlines)
        book.category = category
        saveContext()
    }

    func deleteBook(book: Book) {
        context.delete(book)
        saveContext()
    }

    func createMember(name: String, email: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let member = Member(context: context)
        member.id = UUID()
        member.name = cleanName
        member.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        member.joinedAt = Date()
        saveContext()
    }

    func deleteMember(member: Member) {
        context.delete(member)
        saveContext()
    }

    @discardableResult
    func borrowBook(member: Member, book: Book, dueDays: Int = 7) -> Bool {
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
        saveContext()
        return true
    }

    func returnLoan(loan: Loan) {
        guard loan.returnedAt == nil else { return }

        loan.returnedAt = Date()
        loan.status = "Returned"
        loan.book?.isAvailable = true
        saveContext()
    }

    private func seedIfNeeded() {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
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

        saveContext()
    }

    private func saveContext() {
        do {
            try context.save()
            refreshAll()
        } catch {
            context.rollback()
        }
    }
}
