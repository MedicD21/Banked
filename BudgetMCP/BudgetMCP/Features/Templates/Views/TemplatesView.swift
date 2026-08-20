import SwiftUI

struct TemplatesView: View {
    @State var viewModel: TemplatesViewModel
    let onApplied: ([BudgetCategory]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingTemplate: BudgetTemplate?

    var body: some View {
        NavigationStack {
            List(BudgetTemplate.all) { template in
                Button {
                    pendingTemplate = template
                } label: {
                    TemplateRow(template: template)
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.Colors.surface)
                .disabled(viewModel.isApplying)
            }
            .themedScreenBackground()
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isApplying)
                }
            }
            .confirmationDialog(
                pendingTemplate.map { "Add \($0.categories.count) categories from \($0.name)?" } ?? "",
                isPresented: .constant(pendingTemplate != nil),
                titleVisibility: .visible
            ) {
                Button("Add Categories") {
                    guard let template = pendingTemplate else { return }
                    pendingTemplate = nil
                    Task {
                        let created = await viewModel.apply(template)
                        if !created.isEmpty {
                            onApplied(created)
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { pendingTemplate = nil }
            }
            .alert("Couldn't Add Categories", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
            .overlay {
                if viewModel.isApplying {
                    ProgressView("Adding categories…")
                        .padding(Theme.Spacing.lg)
                        .background(Theme.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
            }
        }
        .themedRoot()
        .presentationBackground(Theme.Colors.canvas)
        .presentationCornerRadius(Theme.Radius.lg)
        .presentationDragIndicator(.visible)
    }
}

private struct TemplateRow: View {
    let template: BudgetTemplate

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: template.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.Colors.accentBright)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(template.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(template.categories.map(\.name).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    TemplatesView(viewModel: TemplatesViewModel(apiClient: PreviewAPIClient()), onApplied: { _ in })
}
