import SwiftUI

struct ReconcileView: View {
    @State var viewModel: ReconcileViewModel
    @State private var selectedTransaction: UncategorizedTransaction?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.transactions.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "checkmark.circle",
                        description: Text("No uncategorized transactions — everything is reconciled.")
                    )
                }

                ForEach(viewModel.transactions) { transaction in
                    Button {
                        selectedTransaction = transaction
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Reconcile")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .disabled(viewModel.isReconciling)
            .sheet(item: $selectedTransaction) { transaction in
                CategoryPickerSheet(
                    transaction: transaction,
                    categories: viewModel.categories
                ) { category in
                    selectedTransaction = nil
                    Task { await viewModel.reconcile(transactionId: transaction.transactionId, categoryId: category.id) }
                }
            }
            .alert("Couldn't Load Transactions", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
            .alert(viewModel.lastResultMessage ?? "", isPresented: .constant(viewModel.lastResultMessage != nil)) {
                Button("OK") { viewModel.dismissResultMessage() }
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: UncategorizedTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchantName ?? transaction.name)
                    .font(.body)
                Text(transaction.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(transaction.amountDollars, format: .currency(code: "USD"))
                .font(.headline)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct CategoryPickerSheet: View {
    let transaction: UncategorizedTransaction
    let categories: [BudgetCategory]
    let onPick: (BudgetCategory) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(categories) { category in
                Button {
                    onPick(category)
                } label: {
                    HStack {
                        Text(category.name)
                        Spacer()
                        Text(category.remainingDollars, format: .currency(code: "USD"))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(transaction.merchantName ?? transaction.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReconcileView(viewModel: ReconcileViewModel(apiClient: PreviewAPIClient()))
}
