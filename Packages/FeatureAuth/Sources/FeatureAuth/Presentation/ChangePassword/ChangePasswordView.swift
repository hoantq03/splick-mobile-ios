import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct ChangePasswordView: View {
    @StateObject private var viewModel: ChangePasswordViewModel
    @Environment(\.dismiss) private var dismiss
    private let onPasswordChanged: ((User) -> Void)?

    public init(
        viewModel: @autoclosure @escaping () -> ChangePasswordViewModel,
        onPasswordChanged: ((User) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onPasswordChanged = onPasswordChanged
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                Picker("Verify with", selection: $viewModel.method) {
                    ForEach(ChangePasswordViewModel.VerificationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                switch viewModel.method {
                case .currentPassword:
                    SplickTextField(
                        "Current password",
                        text: $viewModel.currentPassword,
                        isSecure: true,
                        errorMessage: viewModel.currentPasswordError,
                        icon: "lock"
                    )
                    .textContentType(.password)
                case .emailCode:
                    VStack(spacing: SplickTheme.Spacing.sm) {
                        if let message = viewModel.otpInfoMessage {
                            Text(message)
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        SplickButton("Send code to email", style: .secondary) {
                            Task { await viewModel.requestEmailCode() }
                        }
                        SplickOtpField(code: $viewModel.otpCode, errorMessage: viewModel.otpError)
                    }
                }

                SplickTextField(
                    "New password",
                    text: $viewModel.newPassword,
                    isSecure: true,
                    errorMessage: viewModel.passwordError,
                    icon: "lock"
                )
                .textContentType(.newPassword)
                .onChange(of: viewModel.newPassword) { _ in viewModel.validatePasswordField() }

                SplickTextField(
                    "Confirm password",
                    text: $viewModel.confirmPassword,
                    isSecure: true,
                    errorMessage: viewModel.confirmPasswordError,
                    icon: "lock.fill"
                )
                .textContentType(.newPassword)
                .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }

                if let error = viewModel.state.error {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                SplickButton(
                    "Update password",
                    isLoading: viewModel.state.isLoading,
                    isDisabled: submitDisabled
                ) {
                    Task { await viewModel.changePassword() }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.top, SplickTheme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SplickTheme.Colors.background)
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.state) { state in
            if case .loaded(let session) = state {
                onPasswordChanged?(session.user)
                dismiss()
            }
        }
    }

    private var submitDisabled: Bool {
        !viewModel.passwordStrength.isStrong
            || viewModel.newPassword != viewModel.confirmPassword
            || (viewModel.method == .currentPassword && viewModel.currentPassword.isEmpty)
            || (viewModel.method == .emailCode && viewModel.otpCode.count != 6)
    }
}
