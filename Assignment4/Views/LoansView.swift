import SwiftUI

struct LoansView: View {
    @EnvironmentObject var holder: LibraryHolder
    @Environment(\.managedObjectContext) private var context

    private var sortedLoans: [Loan] {
        holder.loans.sorted { ($0.borrowedAt ?? .distantPast) > ($1.borrowedAt ?? .distantPast) }
    }

    var body: some View {
        Group {
            if holder.loans.isEmpty {
                ContentUnavailableView("No Loans", systemImage: "clock.badge.exclamationmark", description: Text("Borrowed books will appear here."))
            } else {
                List {
                    ForEach(sortedLoans, id: \.objectID) { loan in
                        LoanRow(loan: loan) {
                            holder.returnLoan(loan, context)
                        }
                    }
                }
            }
        }
        .navigationTitle("Loans")
        .onAppear {
            holder.refreshLoans(context)
            holder.refreshBooks(context)
            holder.refreshMembers(context)
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
            HStack {
                VStack(alignment: .leading) {
                    Text(loan.book?.title ?? "Unknown Book")
                        .font(.headline)
                    Text(loan.member?.name ?? "Unknown Member")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(isActive ? "Active" : "Returned")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isActive ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text("Borrowed: \(loan.borrowedAt ?? .now, style: .date)")
                .font(.caption)
            Text("Due: \(loan.dueAt ?? .now, style: .date)")
                .font(.caption)
                .foregroundStyle(isOverdue ? .red : .secondary)

            if isOverdue {
                Text("Overdue")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }

            if isActive {
                Button("Return") {
                    onReturn()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(isOverdue ? Color.red.opacity(0.08) : Color.clear)
    }
}

#Preview {
    NavigationStack {
        LoansView()
    }
}
