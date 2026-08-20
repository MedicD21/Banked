import SwiftUI

struct ReconcileView: View {
    @State var viewModel: ReconcileViewModel
    @State private var selectedTransaction: UncategorizedTransaction?
    @State private var searchText = ""

    private var filteredTransactions: [UncategorizedTransaction] {
        guard !searchText.isEmpty else { return viewModel.transactions }
        return viewModel.transactions.filter {
            ($0.merchantName ?? $0.name).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.transactions.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "checkmark.circle",
                        description: Text("No uncategorized transactions — everything is reconciled.")
                    )
                    .listRowBackground(Color.clear)
                } else if filteredTransactions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                }

                ForEach(filteredTransactions) { transaction in
                    Button {
                        selectedTransaction = transaction
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.Colors.surface)
                }
            }
            .themedScreenBackground()
            .navigationTitle("Reconcile")
            .searchable(text: $searchText, prompt: "Search merchants")
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
            .sensoryFeedback(.success, trigger: viewModel.lastResultMessage)
        }
    }
}

private struct TransactionRow: View {
    let transaction: UncategorizedTransaction

    /// Plaid convention: a positive amount is money leaving the account (an
    /// expense); negative is money coming in (a refund or deposit).
    private var isExpense: Bool { transaction.amountDollars > 0 }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchantName ?? transaction.name)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(transaction.date)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            (Text(isExpense ? "-" : "+") + Text(abs(transaction.amountDollars), format: .currency(code: "USD")))
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(isExpense ? Theme.Colors.negative : Theme.Colors.positive)
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
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(category.remainingDollars, format: .currency(code: "USD"))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.Colors.surface)
            }
            .themedScreenBackground()
            .navigationTitle(transaction.merchantName ?? transaction.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .themedRoot()
        .presentationBackground(Theme.Colors.canvas)
        .presentationCornerRadius(Theme.Radius.lg)
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ReconcileView(viewModel: ReconcileViewModel(apiClient: PreviewAPIClient()))
        .themedRoot()
}
