import SwiftUI

struct BudgetOverviewView: View {
    @State var viewModel: BudgetOverviewViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BalanceSummaryCard(
                        availableDollars: viewModel.availableDollars,
                        assignedDollars: viewModel.assignedDollars,
                        safeToSpendDollars: viewModel.safeToSpendDollars,
                        isLoading: viewModel.isLoading
                    )
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)

                if viewModel.categories.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Categories Yet", systemImage: "chart.pie")
                    } description: {
                        Text("Add your first category, or start from a template.")
                    } actions: {
                        Button("Browse Templates") { viewModel.showingTemplates = true }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.Colors.accent)
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.groupedCategories) { group in
                    Section(group.name) {
                        ForEach(group.categories) { category in
                            NavigationLink {
                                CategoryDetailView(
                                    viewModel: CategoryDetailViewModel(apiClient: appState.apiClient, category: category),
                                    existingGroups: viewModel.existingGroupNames,
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
                    .headerProminence(.increased)
                }
            }
            .themedScreenBackground()
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            viewModel.showingAddCategory = true
                        } label: {
                            Label("New Category", systemImage: "plus")
                        }
                        Button {
                            viewModel.showingTemplates = true
                        } label: {
                            Label("Browse Templates", systemImage: "square.grid.2x2")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        viewModel.showingMoveFunds = true
                    } label: {
                        Label("Move Money", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(viewModel.categories.count < 2)
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showingAddCategory) {
                CategoryEditorView(
                    viewModel: CategoryEditorViewModel(apiClient: viewModel.apiClient, mode: .create, existingGroups: viewModel.existingGroupNames),
                    onSave: { viewModel.upsert($0) }
                )
            }
            .sheet(isPresented: $viewModel.showingTemplates) {
                TemplatesView(
                    viewModel: TemplatesViewModel(apiClient: viewModel.apiClient),
                    onApplied: { created in created.forEach { viewModel.upsert($0) } }
                )
            }
            .sheet(isPresented: $viewModel.showingMoveFunds) {
                MoveFundsView(
                    viewModel: MoveFundsViewModel(categories: viewModel.categories) { fromId, toId, amount in
                        await viewModel.moveFunds(fromCategoryId: fromId, toCategoryId: toId, amountDollars: amount)
                    },
                    onMoved: {}
                )
            }
            .alert("Couldn't Load Categories", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.categories.count)
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
                if category.rollover {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Spacer()
                Text(category.remainingDollars, format: .currency(code: "USD"))
                    .font(.headline)
                    .fontDesign(.rounded)
                    .contentTransition(.numericText())
                    .foregroundStyle(category.remainingDollars < 0 ? Theme.Colors.negative : Theme.Colors.textPrimary)
            }

            if let dueStatus = category.dueStatus {
                DueDateBadge(status: dueStatus)
            }

            ProgressView(value: progress)
                .tint(category.remainingDollars < 0 ? Theme.Colors.negative : Theme.Colors.accent)
                .animation(.smooth(duration: 0.5), value: progress)

            HStack {
                Text("\(category.spentDollars, format: .currency(code: "USD")) spent")
                Spacer()
                Text("\(category.allocatedDollars, format: .currency(code: "USD")) allocated")
            }
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
        .animation(.smooth(duration: 0.4), value: category.remainingDollars)
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
