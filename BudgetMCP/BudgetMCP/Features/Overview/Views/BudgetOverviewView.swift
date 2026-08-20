import SwiftUI

struct BudgetOverviewView: View {
    @State var viewModel: BudgetOverviewViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                if viewModel.categories.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Categories Yet",
                        systemImage: "chart.pie",
                        description: Text("Tap + to create your first budget category.")
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.categories) { category in
                    NavigationLink {
                        CategoryDetailView(
                            viewModel: CategoryDetailViewModel(apiClient: appState.apiClient, category: category),
                            onCategoryUpdated: { viewModel.upsert($0) },
                            onCategoryDeleted: { viewModel.remove($0) }
                        )
                    } label: {
                        CategoryRow(category: category)
                    }
                    .listRowBackground(Theme.Colors.surface)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteCategory(category) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(viewModel.deletingCategoryIds.contains(category.id))
                    }
                }
            }
            .themedScreenBackground()
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showingAddCategory) {
                CategoryEditorView(
                    viewModel: CategoryEditorViewModel(apiClient: viewModel.apiClient, mode: .create),
                    onSave: { viewModel.upsert($0) }
                )
            }
            .alert("Couldn't Load Categories", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
    }
}

private struct CategoryRow: View {
    let category: BudgetCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(category.remainingDollars, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(category.remainingDollars < 0 ? Theme.Colors.negative : Theme.Colors.textPrimary)
            }

            ProgressView(value: progress)
                .tint(category.remainingDollars < 0 ? Theme.Colors.negative : Theme.Colors.accent)

            HStack {
                Text("\(category.spentDollars, format: .currency(code: "USD")) spent")
                Spacer()
                Text("\(category.allocatedDollars, format: .currency(code: "USD")) allocated")
            }
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var progress: Double {
        guard category.allocatedDollars > 0 else { return 0 }
        return min(category.spentDollars / category.allocatedDollars, 1)
    }
}

#Preview {
    BudgetOverviewView(viewModel: BudgetOverviewViewModel(apiClient: PreviewAPIClient()))
        .environment(AppState())
        .themedRoot()
}
