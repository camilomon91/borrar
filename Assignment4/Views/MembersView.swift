import SwiftUI
import CoreData

struct MembersView: View {
    @EnvironmentObject var holder: LibraryHolder
    @State private var showingAddMember = false

    var body: some View {
        Group {
            if holder.members.isEmpty {
                Text("No Members")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(holder.members, id: \.objectID) { member in
                        NavigationLink {
                            MemberDetailView(member: member)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(member.name ?? "Unnamed")
                                Text(member.email ?? "No Email")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            holder.deleteMember(member: holder.members[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Members")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    showingAddMember = true
                }
            }
        }
        .sheet(isPresented: $showingAddMember) {
            AddMemberView()
                .environmentObject(holder)
        }
        .onAppear {
            holder.refreshMembers()
            holder.refreshLoans()
            holder.refreshBooks()
        }
    }
}

private struct AddMemberView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
            }
            .navigationTitle("Add Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        holder.createMember(name: name, email: email)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct MemberDetailView: View {
    @EnvironmentObject var holder: LibraryHolder

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
            Section("Active Loans") {
                if activeLoans.isEmpty {
                    Text("No active loans")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeLoans, id: \.objectID) { loan in
                        Text(loan.book?.title ?? "Unknown Book")
                    }
                }
            }

            Section("Past Loans") {
                if pastLoans.isEmpty {
                    Text("No past loans")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pastLoans, id: \.objectID) { loan in
                        Text(loan.book?.title ?? "Unknown Book")
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
            holder.refreshLoans()
            holder.refreshBooks()
        }
    }
}

private struct BorrowBookView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.dismiss) private var dismiss

    let member: Member

    @State private var selectedBookID: NSManagedObjectID?
    @State private var dueDays = 7
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    ForEach(holder.books, id: \.objectID) { book in
                        let available = book.isAvailable
                        Button {
                            if available { selectedBookID = book.objectID }
                        } label: {
                            HStack {
                                Text(book.title ?? "Untitled")
                                Spacer()
                                if !available {
                                    Text("Unavailable")
                                        .foregroundStyle(.red)
                                } else if selectedBookID == book.objectID {
                                    Text("Selected")
                                }
                            }
                        }
                        .disabled(!available)
                    }
                }

                Section("Due in") {
                    Picker("Days", selection: $dueDays) {
                        Text("7").tag(7)
                        Text("14").tag(14)
                    }
                    .pickerStyle(.segmented)
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
            message = "Select an available book."
            return
        }

        let success = holder.borrowBook(member: member, book: book, dueDays: dueDays)
        if success {
            dismiss()
        } else {
            message = "Book is unavailable."
        }
    }
}

#Preview {
    NavigationStack {
        MembersView()
    }
}
