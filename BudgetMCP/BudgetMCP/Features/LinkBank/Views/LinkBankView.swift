import SwiftUI
import LinkKit

struct LinkBankView: View {
    @State var viewModel: LinkBankViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "building.columns.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("Link a Bank Account")
                .font(.title2.bold())

            Text("Connect a real account via Plaid. Balances and transactions sync once a day and are only used to reconcile against your fake budget — nothing here can move real money.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            switch viewModel.status {
            case .idle:
                Button {
                    Task { await viewModel.startLink() }
                } label: {
                    Text("Connect Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

            case .fetchingLinkToken, .exchanging:
                ProgressView()

            case .readyToPresent(let linkToken):
                PlaidLinkPresenter(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        Task { await viewModel.completeLink(publicToken: publicToken) }
                    },
                    onExit: {
                        viewModel.cancelLink()
                    }
                )
                .frame(width: 0, height: 0)

            case .success:
                Label("Account Linked", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .alert("Couldn't Link Account", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
        .onChange(of: viewModel.status) { newStatus in
            if newStatus == .success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
            }
        }
    }
}

/// Bridges Plaid's UIKit-based LinkKit presentation into SwiftUI. Presents
/// itself as soon as it appears, then reports success/exit back via closures.
private struct PlaidLinkPresenter: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (String) -> Void
    let onExit: () -> Void

    func makeUIViewController(context: Context) -> PresentingViewController {
        PresentingViewController(linkToken: linkToken, onSuccess: onSuccess, onExit: onExit)
    }

    func updateUIViewController(_ uiViewController: PresentingViewController, context: Context) {}

    final class PresentingViewController: UIViewController {
        private let linkToken: String
        private let onSuccess: (String) -> Void
        private let onExit: () -> Void
        private var handler: Handler?
        private var hasPresented = false

        init(linkToken: String, onSuccess: @escaping (String) -> Void, onExit: @escaping () -> Void) {
            self.linkToken = linkToken
            self.onSuccess = onSuccess
            self.onExit = onExit
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !hasPresented else { return }
            hasPresented = true
            presentLink()
        }

        private func presentLink() {
            var configuration = LinkTokenConfiguration(token: linkToken) { [weak self] success in
                PlaidLinkOAuthCoordinator.activeHandler = nil
                self?.onSuccess(success.publicToken)
            }
            configuration.onExit = { [weak self] _ in
                PlaidLinkOAuthCoordinator.activeHandler = nil
                self?.onExit()
            }

            let result = Plaid.create(configuration)
            switch result {
            case .success(let handler):
                self.handler = handler
                PlaidLinkOAuthCoordinator.activeHandler = handler
                handler.open(presentUsing: .viewController(self))
            case .failure:
                onExit()
            }
        }
    }
}

/// Holds the in-flight Plaid `Handler` so the app-level `onOpenURL` (see
/// `BudgetMCPApp`) can hand an OAuth redirect back to it. Real institutions
/// (Chase, Bank of America, etc.) require this redirect round-trip in
/// Development/Production; Sandbox test institutions don't use it.
enum PlaidLinkOAuthCoordinator {
    static var activeHandler: Handler?
}

#Preview {
    LinkBankView(viewModel: LinkBankViewModel(apiClient: PreviewAPIClient()))
}
