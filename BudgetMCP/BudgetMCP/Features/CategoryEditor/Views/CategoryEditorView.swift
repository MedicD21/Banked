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
    @State private var didSave = false
    @State private var didDelete = false

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
                    Text("Allocation resets \(viewModel.period.cadenceDescription).")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Section {
                    Toggle("Due Date", isOn: $viewModel.hasDueDate.animation(.snappy(duration: 0.3)))
                        .tint(Theme.Colors.accent)

                    if viewModel.hasDueDate {
                        DatePicker("Date", selection: $viewModel.dueDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .transition(.blurReplace)
                    }
                }
                .listRowBackground(Theme.Colors.surface)

                Section {
                    TextField("Group (e.g. Bills, Fun)", text: $viewModel.groupName)

                    if !viewModel.existingGroups.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(viewModel.existingGroups, id: \.self) { group in
                                    Button {
                                        withAnimation(.snappy(duration: 0.25)) { viewModel.groupName = group }
                                    } label: {
                                        Text(group)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, Theme.Spacing.md)
                                            .padding(.vertical, 6)
                                            .background(
                                                viewModel.groupName == group ? Theme.Colors.accent.opacity(0.25) : Theme.Colors.surfaceElevated,
                                                in: Capsule()
                                            )
                                            .foregroundStyle(viewModel.groupName == group ? Theme.Colors.accentBright : Theme.Colors.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.lg, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg))
                    }
                } header: {
                    Text("Group")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .listRowBackground(Theme.Colors.surface)

                Section {
                    Toggle("Auto-Assign Each Period", isOn: $viewModel.autoAssign)
                        .tint(Theme.Colors.accent)
                    Toggle("Roll Over Unspent Balance", isOn: $viewModel.rollover)
                        .tint(Theme.Colors.accent)
                } footer: {
                    Text("Auto-Assign refills this category's allocation every period. Rollover carries any unspent (or overspent) balance into the next one instead of resetting.")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .listRowBackground(Theme.Colors.surface)

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
                                    didSave = true
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
                            didDelete = true
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
        .presentationBackground(Theme.Colors.canvas)
        .presentationCornerRadius(Theme.Radius.lg)
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: didSave)
        .sensoryFeedback(.warning, trigger: didDelete)
    }
}

#Preview("Create") {
    CategoryEditorView(
        viewModel: CategoryEditorViewModel(apiClient: PreviewAPIClient(), mode: .create, existingGroups: ["Everyday", "Bills", "Savings"]),
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
