import SwiftUI
import CoreData

struct MembersView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.managedObjectContext) private var context
    @State private var showingAddMember = false

    var body: some View {
        Group {
            if holder.members.isEmpty {
                ContentUnavailableView("No Members", systemImage: "person.2", description: Text("Add a member to begin creating loans."))
            } else {
                List {
                    ForEach(holder.members, id: \.objectID) { member in
                        NavigationLink {
                            MemberDetailView(member: member)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(member.name ?? "Unnamed")
                                    .font(.headline)
                                Text(member.email ?? "No Email")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            holder.deleteMember(holder.members[index], context)
                        }
                    }
                }
            }
        }
        .navigationTitle("Members")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddMember = true
                } label: {
                    Label("Add Member", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMember) {
            AddMemberView()
                .environmentObject(holder)
        }
        .onAppear {
            holder.refreshMembers(context)
            holder.refreshLoans(context)
        }
    }
}

private struct AddMemberView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var name = ""
    @State private var email = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle("Add Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        holder.createMember(name: name, email: email, context)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

private struct MemberDetailView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.managedObjectContext) private var context

    let member: Member
    @State private var showingBorrow = false

    private var memberLoans: [Loan] {
        holder.loans.filter { $0.member?.objectID == member.objectID }
    }

    private var activeLoans: [Loan] {
        memberLoans.filter { $0.returnedAt == nil }
    }

    private var pastLoans: [Loan] {
        memberLoans.filter { $0.returnedAt != nil }
    }

    var body: some View {
        List {
            Section {
                Text(member.email ?? "No email")
                    .foregroundStyle(.secondary)
            }

            Section("Active Loans") {
                if activeLoans.isEmpty {
                    Text("No active loans")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeLoans, id: \.objectID) { loan in
                        LoanSummaryRow(loan: loan)
                    }
                }
            }

            Section("Past Loans") {
                if pastLoans.isEmpty {
                    Text("No past loans")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pastLoans, id: \.objectID) { loan in
                        LoanSummaryRow(loan: loan)
                    }
                }
            }
        }
        .navigationTitle(member.name ?? "Member")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Borrow a Book") {
                    showingBorrow = true
                }
            }
        }
        .sheet(isPresented: $showingBorrow) {
            BorrowBookView(member: member)
                .environmentObject(holder)
        }
        .onAppear {
            holder.refreshLoans(context)
            holder.refreshBooks(context)
        }
    }
}

private struct BorrowBookView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    let member: Member

    @State private var selectedBookID: NSManagedObjectID?
    @State private var dueDays = 7
    @State private var message: String?

    private let dueOptions = [7, 14]

    var body: some View {
        NavigationStack {
            Form {
                if holder.books.isEmpty {
                    Text("No books in library yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Select Book") {
                        ForEach(holder.books, id: \.objectID) { book in
                            let available = book.isAvailable
                            Button {
                                if available {
                                    selectedBookID = book.objectID
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(book.title ?? "Untitled")
                                        Text(book.author ?? "Unknown")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !available {
                                        Text("Unavailable")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    } else if selectedBookID == book.objectID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .disabled(!available)
                        }
                    }

                    Section("Due Date") {
                        Picker("Loan Duration", selection: $dueDays) {
                            ForEach(dueOptions, id: \.self) { value in
                                Text("\(value) days").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let message {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Borrow Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        confirmBorrow()
                    }
                    .disabled(selectedBookID == nil)
                }
            }
        }
    }

    private func confirmBorrow() {
        guard let selectedBookID,
              let book = holder.books.first(where: { $0.objectID == selectedBookID }) else {
            message = "Please select an available book."
            return
        }

        let success = holder.borrowBook(member: member, book: book, dueDays: dueDays, context)
        if success {
            dismiss()
        } else {
            message = "That book is no longer available."
        }
    }
}

private struct LoanSummaryRow: View {
    let loan: Loan

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(loan.book?.title ?? "Unknown Book")
                .font(.headline)
            Text("Borrowed: \(loan.borrowedAt ?? .now, style: .date)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(loan.returnedAt == nil ? "Active" : "Returned")
                .font(.caption)
                .foregroundStyle(loan.returnedAt == nil ? .blue : .green)
        }
    }
}

#Preview {
    NavigationStack {
        MembersView()
    }
}
