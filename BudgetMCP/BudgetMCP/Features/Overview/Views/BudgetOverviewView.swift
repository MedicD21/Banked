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
                        description: Text("Create a category from Claude to get started.")
                    )
                }

                ForEach(viewModel.categories) { category in
                    NavigationLink {
                        CategoryDetailView(
                            category: category,
                            viewModel: CategoryDetailViewModel(apiClient: appState.apiClient, categoryId: category.id)
                        )
                    } label: {
                        CategoryRow(category: category)
                    }
                }
            }
            .navigationTitle("Budget")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
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
                Spacer()
                Text(category.remainingDollars, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(category.remainingDollars < 0 ? .red : .primary)
            }

            ProgressView(value: progress)
                .tint(category.remainingDollars < 0 ? .red : .accentColor)

            HStack {
                Text("\(category.spentDollars, format: .currency(code: "USD")) spent")
                Spacer()
                Text("\(category.allocatedDollars, format: .currency(code: "USD")) allocated")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
}
