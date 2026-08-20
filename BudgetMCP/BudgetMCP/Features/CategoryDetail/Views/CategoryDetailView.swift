import SwiftUI

struct CategoryDetailView: View {
    @State var viewModel: CategoryDetailViewModel
    var existingGroups: [String] = []
    var onCategoryUpdated: (BudgetCategory) -> Void = { _ in }
    var onCategoryDeleted: (BudgetCategory) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                LabeledContent("Allocated") {
                    Text(viewModel.category.allocatedDollars, format: .currency(code: "USD"))
                        .fontDesign(.rounded)
                }
                LabeledContent("Spent") {
                    Text(viewModel.category.spentDollars, format: .currency(code: "USD"))
                        .fontDesign(.rounded)
                }
                LabeledContent("Remaining") {
                    Text(viewModel.category.remainingDollars, format: .currency(code: "USD"))
                        .fontDesign(.rounded)
                        .contentTransition(.numericText())
                        .foregroundStyle(viewModel.category.remainingDollars < 0 ? Theme.Colors.negative : Theme.Colors.textPrimary)
                }
                LabeledContent("Period", value: BudgetPeriod(rawValue: viewModel.category.period.lowercased())?.displayName ?? viewModel.category.period.capitalized)

                if let group = viewModel.category.groupName, !group.isEmpty {
                    LabeledContent("Group", value: group)
                }

                if let dueStatus = viewModel.category.dueStatus {
                    LabeledContent("Due Date") {
                        DueDateBadge(status: dueStatus)
                    }
                }
            }
            .listRowBackground(Theme.Colors.surface)
            .animation(.smooth(duration: 0.4), value: viewModel.category.remainingDollars)

            if viewModel.category.autoAssign || viewModel.category.rollover {
                Section {
                    if viewModel.category.autoAssign {
                        Label("Auto-assigns each period", systemImage: "repeat")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if viewModel.category.rollover {
                        Label("Rolls over unspent balance", systemImage: "arrow.turn.down.right")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .listRowBackground(Theme.Colors.surface)
            }

            if viewModel.entries.count >= 2 {
                Section("Spending Trend") {
                    SpendingTrendChart(entries: viewModel.entries)
                }
                .listRowBackground(Theme.Colors.surface)
            }

            Section("Ledger History") {
                if viewModel.entries.isEmpty && !viewModel.isLoading {
                    Text("No activity yet.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                ForEach(viewModel.entries) { entry in
                    LedgerEntryRow(entry: entry)
                }
            }
            .listRowBackground(Theme.Colors.surface)
        }
        .themedScreenBackground()
        .navigationTitle(viewModel.category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.showingEditor) {
            CategoryEditorView(
                viewModel: CategoryEditorViewModel(apiClient: viewModel.apiClient, mode: .edit(viewModel.category), existingGroups: existingGroups),
                onSave: { updated in
                    viewModel.apply(updated)
                    onCategoryUpdated(updated)
                },
                onDelete: {
                    onCategoryDeleted(viewModel.category)
                    dismiss()
                }
            )
        }
        .alert("Couldn't Load History", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }
}

private struct LedgerEntryRow: View {
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.memo ?? entry.entryType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.body)
                Spacer()
                Text(entry.amountDollars, format: .currency(code: "USD"))
                    .fontDesign(.rounded)
                    .foregroundStyle(entry.amountDollars < 0 ? Theme.Colors.negative : Theme.Colors.positive)
            }
            Text(isoTimestamp: entry.createdAt, format: .dateTime.month().day().year().hour().minute())
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            viewModel: CategoryDetailViewModel(
                apiClient: PreviewAPIClient(),
                category: BudgetCategory(id: "1", name: "Groceries", allocatedDollars: 500, spentDollars: 210.5, remainingDollars: 289.5, period: "monthly")
            )
        )
    }
    .themedRoot()
}
