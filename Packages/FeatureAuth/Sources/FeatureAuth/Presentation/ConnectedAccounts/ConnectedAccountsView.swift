import SwiftUI
import DesignSystem
import SplickDomain

public struct ConnectedAccountsView: View {
    @StateObject private var viewModel: ConnectedAccountsViewModel

    public init(viewModel: @autoclosure @escaping () -> ConnectedAccountsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        List {
            if let info = viewModel.infoMessage {
                Text(info)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }

            if let accounts = viewModel.accounts {
                providerRow(
                    title: "Google",
                    provider: accounts.google,
                    actionTitle: accounts.google.isLinked ? "Unlink" : "Connect",
                    isLoading: viewModel.isLinkingGoogle,
                    isDisabled: !viewModel.isGoogleLinkAvailable && !accounts.google.isLinked
                ) {
                    if accounts.google.isLinked {
                        viewModel.showUnlinkSheet = true
                    } else {
                        Task { await viewModel.linkGoogle() }
                    }
                }

                providerRow(
                    title: "Email & password",
                    provider: accounts.emailPassword,
                    actionTitle: nil,
                    isLoading: false,
                    isDisabled: true
                ) {}

                providerRow(
                    title: "Phone",
                    provider: accounts.phone,
                    actionTitle: nil,
                    isLoading: false,
                    isDisabled: true
                ) {}
            }
        }
        .navigationTitle("Connected accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $viewModel.showUnlinkSheet) {
            unlinkSheet
        }
    }

    @ViewBuilder
    private func providerRow(
        title: String,
        provider: ConnectedProvider,
        actionTitle: String?,
        isLoading: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                Text(title)
                    .font(SplickTheme.Typography.body)
                Text(provider.isLinked ? (provider.detail ?? "Linked") : "Not connected")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            Spacer()
            if let actionTitle {
                Button(actionTitle, action: action)
                    .disabled(isDisabled || isLoading)
            }
        }
    }

    private var unlinkSheet: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                Picker("Verify with", selection: $viewModel.unlinkMethod) {
                    ForEach(ConnectedAccountsViewModel.VerificationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                switch viewModel.unlinkMethod {
                case .password:
                    SplickTextField("Password", text: $viewModel.unlinkPassword, isSecure: true, icon: "lock")
                case .emailCode:
                    SplickButton("Send code to email", style: .secondary) {
                        Task { await viewModel.requestUnlinkCode() }
                    }
                    SplickTextField("Verification code", text: $viewModel.unlinkOtpCode, icon: "number")
                        .keyboardType(.numberPad)
                }

                SplickButton("Unlink Google", style: .destructive, isLoading: viewModel.isUnlinkingGoogle) {
                    Task { _ = await viewModel.unlinkGoogle() }
                }
            }
            .padding()
            .navigationTitle("Unlink Google")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showUnlinkSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
