import SwiftUI
import DesignSystem
import Common

public struct RegisterView: View {
    @StateObject private var viewModel: RegisterViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: @autoclosure @escaping () -> RegisterViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                headerSection
                formSection
                actionSection
            }
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.top, SplickTheme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SplickTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Text("Create Account")
                .font(SplickTheme.Typography.largeTitle)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Text("Join your friends on Splick")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .padding(.bottom, SplickTheme.Spacing.md)
    }

    private var formSection: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            SplickTextField(
                "Email",
                text: $viewModel.email,
                errorMessage: viewModel.emailError,
                icon: "envelope"
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            SplickTextField(
                "Username",
                text: $viewModel.username,
                errorMessage: viewModel.usernameError,
                icon: "person"
            )
            .textContentType(.username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            SplickTextField(
                "Password",
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock"
            )
            .textContentType(.newPassword)

            SplickTextField(
                "Confirm Password",
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: viewModel.confirmPasswordError,
                icon: "lock.fill"
            )
            .textContentType(.newPassword)
        }
    }

    private var actionSection: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            if let error = viewModel.state.error {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .multilineTextAlignment(.center)
            }

            SplickButton(
                "Create Account",
                isLoading: viewModel.state.isLoading,
                isDisabled: viewModel.email.isEmpty || viewModel.username.isEmpty
                    || viewModel.password.isEmpty || viewModel.confirmPassword.isEmpty
            ) {
                Task { await viewModel.register() }
            }
        }
    }
}
