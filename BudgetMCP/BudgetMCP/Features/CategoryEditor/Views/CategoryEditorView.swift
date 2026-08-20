import SwiftUI

/// Shared create/edit form for a `BudgetCategory`. Presented as a sheet from
/// both the Overview list (create) and Category Detail (edit).
struct CategoryEditorView: View {
    @State var viewModel: CategoryEditorViewModel
    let onSave: (BudgetCategory) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Category Name", text: $viewModel.name)
                        .focused($nameFieldFocused)
                        .listRowBackground(Theme.Colors.surface)

                    HStack {
                        Text("$")
                            .foregroundStyle(Theme.Colors.textSecondary)
                        TextField("Amount", text: $viewModel.allocatedText)
                            .keyboardType(.decimalPad)
                    }
                    .listRowBackground(Theme.Colors.surface)

                    Picker("Period", selection: $viewModel.period) {
                        ForEach(BudgetPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .listRowBackground(Theme.Colors.surface)
                } header: {
                    Text("Details")
                        .foregroundStyle(Theme.Colors.textSecondary)
                } footer: {
                    Text("Allocation resets at the start of each \(viewModel.period.rawValue.dropLast()) period.")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                if case .edit = viewModel.mode {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isDeleting {
                                    ProgressView()
                                } else {
                                    Text("Delete Category")
                                }
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isSaving || viewModel.isDeleting)
                    }
                    .listRowBackground(Theme.Colors.surface)
                }
            }
            .themedScreenBackground()
            .navigationTitle(viewModel.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving || viewModel.isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                if let saved = await viewModel.save() {
                                    onSave(saved)
                                    dismiss()
                                }
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.isValid)
                    }
                }
            }
            .confirmationDialog(
                "Delete \"\(viewModel.name)\"?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            onDelete?()
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the category and its history. This can't be undone.")
            }
            .alert("Couldn't Save Category", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
        .onAppear {
            if case .create = viewModel.mode {
                nameFieldFocused = true
            }
        }
        .themedRoot()
    }
}

#Preview("Create") {
    CategoryEditorView(
        viewModel: CategoryEditorViewModel(apiClient: PreviewAPIClient(), mode: .create),
        onSave: { _ in }
    )
    .themedRoot()
}

#Preview("Edit") {
    CategoryEditorView(
        viewModel: CategoryEditorViewModel(
            apiClient: PreviewAPIClient(),
            mode: .edit(BudgetCategory(id: "1", name: "Groceries", allocatedDollars: 500, spentDollars: 210.5, remainingDollars: 289.5, period: "monthly"))
        ),
        onSave: { _ in },
        onDelete: {}
    )
    .themedRoot()
}
