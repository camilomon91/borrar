import SwiftUI

struct LoansView: View {
    @EnvironmentObject var holder: LibraryHolder

    private var sortedLoans: [Loan] {
        holder.loans.sorted { ($0.borrowedAt ?? .distantPast) > ($1.borrowedAt ?? .distantPast) }
    }

    var body: some View {
        Group {
            if holder.loans.isEmpty {
                Text("No Loans")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(sortedLoans, id: \.objectID) { loan in
                        LoanRow(loan: loan) {
                            holder.returnLoan(loan: loan)
                        }
                    }
                }
                .listStyle(.plain)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(loan.book?.title ?? "Unknown Book")
            Text(loan.member?.name ?? "Unknown Member")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Borrowed: \(loan.borrowedAt ?? .now, style: .date)")
                .font(.caption)
            Text("Due: \(loan.dueAt ?? .now, style: .date)")
                .font(.caption)
                .foregroundStyle(isOverdue ? .red : .primary)
            Text(isActive ? "Active" : "Returned")
                .font(.caption)
                .foregroundStyle(isActive ? .blue : .green)

            if isActive {
                Button("Return") {
                    onReturn()
                }
            }
        }
        .padding(.vertical, 4)
        .background(isOverdue ? Color.red.opacity(0.1) : Color.clear)
    }
}

#Preview {
    NavigationStack {
        LoansView()
    }
}
