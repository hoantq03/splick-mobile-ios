import SwiftUI
import DesignSystem
import Localization

public struct AccountClosureSheet: View {
    @StateObject private var viewModel: AccountClosureSheetViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    @State private var isPasswordVisible = false
    @State private var confirmedRevealStep = 0

    @Binding private var isPresented: Bool

    public init(
        isPresented: Binding<Bool>,
        viewModel: @autoclosure @escaping () -> AccountClosureSheetViewModel
    ) {
        _isPresented = isPresented
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    warningHeader

                    if let error = viewModel.sheetError {
                        ConnectAccountSheetErrorBanner(message: error)
                    }

                    SplickTextField(
                        languageService.text(.changePasswordCurrentPassword),
                        text: $viewModel.password,
                        isSecure: true,
                        errorMessage: viewModel.passwordError,
                        icon: "lock",
                        showsPasswordVisibilityToggle: true,
                        isPasswordVisible: $isPasswordVisible,
                        passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                        passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
                    )
                    .textContentType(.password)
                    .onChange(of: viewModel.password) { _ in
                        viewModel.onPasswordChanged()
                    }

                    if !viewModel.isVerified {
                        SplickButton(
                            languageService.text(.changePasswordVerifyContinue),
                            isLoading: viewModel.isVerifying,
                            isDisabled: viewModel.isVerifying
                                || viewModel.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            Task { await viewModel.verifyPassword() }
                        }
                    }

                    if viewModel.isVerified {
                        if confirmedRevealStep >= 1 {
                            Text(languageService.text(.accountClosureVerifiedHint))
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .transition(confirmedTransition)
                        }

                        if confirmedRevealStep >= 2 {
                            SplickButton(
                                confirmButtonTitle,
                                style: viewModel.action == .delete ? .destructive : .secondary,
                                isLoading: viewModel.isExecuting,
                                isDisabled: viewModel.isExecuting
                            ) {
                                Task {
                                    let success = await viewModel.executeAction()
                                    if success {
                                        isPresented = false
                                    }
                                }
                            }
                            .transition(confirmedTransition)
                        }
                    }
                }
                .padding(SplickTheme.Spacing.lg)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: viewModel.isVerified)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                viewModel.reset()
                confirmedRevealStep = 0
            }
            .onChange(of: viewModel.isVerified) { verified in
                if verified {
                    animateConfirmedReveal()
                } else {
                    confirmedRevealStep = 0
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var warningHeader: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(warningTint.opacity(0.14))
                    .frame(width: 56, height: 56)

                Image(systemName: warningIconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(warningTint)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(warningMessage)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SplickTheme.Spacing.sm)
    }

    private var sheetTitle: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.profileDeactivate)
        case .delete:
            return languageService.text(.profileDeleteAccount)
        }
    }

    private var warningMessage: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.accountClosureDeactivateWarning)
        case .delete:
            return languageService.text(.accountClosureDeleteWarning)
        }
    }

    private var confirmButtonTitle: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.accountClosureConfirmDeactivate)
        case .delete:
            return languageService.text(.accountClosureConfirmDelete)
        }
    }

    private var warningIconName: String {
        switch viewModel.action {
        case .deactivate:
            return "pause.circle.fill"
        case .delete:
            return "trash.fill"
        }
    }

    private var warningTint: Color {
        switch viewModel.action {
        case .deactivate:
            return SplickTheme.Colors.warning
        case .delete:
            return SplickTheme.Colors.error
        }
    }

    private var confirmedTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    private func animateConfirmedReveal() {
        confirmedRevealStep = 0
        Task { @MainActor in
            for step in 1...2 {
                try? await Task.sleep(nanoseconds: 55_000_000)
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    confirmedRevealStep = step
                }
            }
        }
    }
}
