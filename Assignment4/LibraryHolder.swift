import Foundation
import CoreData
import Combine

@MainActor
final class LibraryHolder: ObservableObject {
    let context: NSManagedObjectContext

    @Published var categories: [Category] = []
    @Published var books: [Book] = []
    @Published var members: [Member] = []
    @Published var loans: [Loan] = []

    init(context: NSManagedObjectContext) {
        self.context = context
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
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        categories = (try? context.fetch(request)) ?? []
    }

    func refreshBooks() {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "title", ascending: true),
            NSSortDescriptor(key: "author", ascending: true)
        ]
        books = (try? context.fetch(request)) ?? []
    }

    func refreshMembers() {
        let request: NSFetchRequest<Member> = Member.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        members = (try? context.fetch(request)) ?? []
    }

    func refreshLoans() {
        let request: NSFetchRequest<Loan> = Loan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "borrowedAt", ascending: false)]
        loans = (try? context.fetch(request)) ?? []
    }

    func createCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let category = Category(context: context)
        category.id = UUID()
        category.name = trimmed
        saveAndRefresh()
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
        saveAndRefresh()
    }

    func updateBook(book: Book, title: String, author: String, isbn: String?, category: Category?) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanAuthor.isEmpty else { return }

        book.title = cleanTitle
        book.author = cleanAuthor
        book.isbn = isbn?.trimmingCharacters(in: .whitespacesAndNewlines)
        book.category = category
        saveAndRefresh()
    }

    func deleteBook(book: Book) {
        context.delete(book)
        saveAndRefresh()
    }

    func createMember(name: String, email: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let member = Member(context: context)
        member.id = UUID()
        member.name = cleanName
        member.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        member.joinedAt = Date()
        saveAndRefresh()
    }

    func deleteMember(member: Member) {
        context.delete(member)
        saveAndRefresh()
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
        saveAndRefresh()
        return true
    }

    func returnLoan(loan: Loan) {
        guard loan.returnedAt == nil else { return }

        loan.returnedAt = Date()
        loan.status = "Returned"
        loan.book?.isAvailable = true
        saveAndRefresh()
    }

    private func saveAndRefresh() {
        do {
            if context.hasChanges {
                try context.save()
            }
            refreshAll()
        } catch {
            context.rollback()
        }
    }
}
