import SwiftUI

struct MoveFundsView: View {
    @State var viewModel: MoveFundsViewModel
    let onMoved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didMove = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("From", selection: $viewModel.fromCategoryId) {
                        ForEach(viewModel.categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    Picker("To", selection: $viewModel.toCategoryId) {
                        ForEach(viewModel.categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                } header: {
                    Text("Between")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .listRowBackground(Theme.Colors.surface)

                Section {
                    HStack {
                        Text("$")
                            .foregroundStyle(Theme.Colors.textSecondary)
                        TextField("Amount", text: $viewModel.amountText)
                            .keyboardType(.decimalPad)
                    }
                } footer: {
                    if let from = viewModel.fromCategory {
                        Text("\(from.name) has \(from.remainingDollars, format: .currency(code: "USD")) remaining.")
                            .foregroundStyle(viewModel.wouldOverdraftSource ? Theme.Colors.warning : Theme.Colors.textTertiary)
                    }
                }
                .listRowBackground(Theme.Colors.surface)
            }
            .themedScreenBackground()
            .navigationTitle("Move Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isMoving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isMoving {
                        ProgressView()
                    } else {
                        Button("Move") {
                            Task {
                                if let response = await viewModel.move(), response.success {
                                    didMove = true
                                    onMoved()
                                    dismiss()
                                }
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.isValid)
                    }
                }
            }
            .alert("Couldn't Move Funds", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
        .themedRoot()
        .presentationBackground(Theme.Colors.canvas)
        .presentationCornerRadius(Theme.Radius.lg)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium])
        .sensoryFeedback(.success, trigger: didMove)
    }
}

#Preview {
    MoveFundsView(
        viewModel: MoveFundsViewModel(
            categories: [
                BudgetCategory(id: "1", name: "Groceries", allocatedDollars: 500, spentDollars: 210.5, remainingDollars: 289.5, period: "monthly"),
                BudgetCategory(id: "2", name: "Dining Out", allocatedDollars: 150, spentDollars: 162, remainingDollars: -12, period: "monthly")
            ],
            onMove: { _, _, _ in nil }
        ),
        onMoved: {}
    )
}
