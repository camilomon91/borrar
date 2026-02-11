import SwiftUI

struct LoansView: View {
    @EnvironmentObject var holder: LibraryHolder

    private var sortedLoans: [Loan] {
        holder.loans.sorted { ($0.borrowedAt ?? .distantPast) > ($1.borrowedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            if holder.loans.isEmpty {
                Text("No loans yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedLoans, id: \.objectID) { loan in
                    LoanRow(loan: loan) {
                        holder.returnLoan(loan: loan)
                    }
                }
            }
        }
        .navigationTitle("Loans")
        .onAppear {
            holder.refreshLoans()
            holder.refreshBooks()
            holder.refreshMembers()
        }
    }
}

private struct LoanRow: View {
    let loan: Loan
    let onReturn: () -> Void

    private var isActive: Bool {
        loan.returnedAt == nil
    }

    private var isOverdue: Bool {
        guard let dueAt = loan.dueAt else { return false }
        return isActive && dueAt < Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loan.book?.title ?? "Unknown Book")
            Text("Member: \(loan.member?.name ?? "Unknown Member")")
            Text("Status: \(isActive ? "Active" : "Returned")")

            Text("Borrowed: \(loan.borrowedAt ?? .now, style: .date)")
            Text("Due: \(loan.dueAt ?? .now, style: .date)")

            if isOverdue {
                Text("Overdue")
                    .foregroundStyle(.red)
            }

            if isActive {
                Button("Return") {
                    onReturn()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoansView()
    }
}
