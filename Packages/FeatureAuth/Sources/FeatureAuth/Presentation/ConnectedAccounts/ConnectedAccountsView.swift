import SwiftUI
import DesignSystem
import Localization
import SplickDomain

public struct ConnectedAccountsView: View {
    @StateObject private var viewModel: ConnectedAccountsViewModel
    @EnvironmentObject private var languageService: LanguageService

    @State private var isEmailPasswordVisible = false
    @State private var isEmailConfirmPasswordVisible = false
    @State private var isUnlinkPasswordVisible = false

    public init(viewModel: @autoclosure @escaping () -> ConnectedAccountsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if let info = viewModel.listInfoMessage {
                    listBanner(text: info, isError: false)
                }
                if let error = viewModel.listErrorMessage {
                    listBanner(text: error, isError: true)
                }

                if let accounts = viewModel.accounts {
                    VStack(spacing: 0) {
                        providerRow(
                            kind: .google,
                            provider: accounts.google,
                            linkAction: accounts.google.isLinked ? nil : .link,
                            unlinkAction: accounts.google.isLinked ? .unlink : nil,
                            isLoading: viewModel.isLinkingGoogle,
                            isDisabled: !viewModel.isGoogleLinkAvailable && !accounts.google.isLinked,
                            showsDivider: true,
                            onLink: { Task { await viewModel.linkGoogle() } },
                            onUnlink: {
                                viewModel.prepareUnlinkSheet()
                                viewModel.showUnlinkSheet = true
                            }
                        )

                        providerRow(
                            kind: .email,
                            provider: accounts.emailPassword,
                            linkAction: accounts.emailPassword.isLinked ? nil : .link,
                            unlinkAction: nil,
                            isLoading: false,
                            isDisabled: false,
                            showsDivider: true,
                            onLink: {
                                viewModel.prepareEmailSheet()
                                viewModel.showConnectEmailSheet = true
                            },
                            onUnlink: {}
                        )

                        providerRow(
                            kind: .phone,
                            provider: accounts.phone,
                            linkAction: accounts.phone.isLinked ? nil : .link,
                            unlinkAction: nil,
                            isLoading: false,
                            isDisabled: false,
                            showsDivider: false,
                            onLink: {
                                viewModel.preparePhoneSheet()
                                viewModel.showConnectPhoneSheet = true
                            },
                            onUnlink: {}
                        )
                    }
                    .background(SplickTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(languageService.text(.profileConnectedAccounts))
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            Task { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $viewModel.showUnlinkSheet) {
            unlinkGoogleSheet
        }
        .sheet(isPresented: $viewModel.showConnectPhoneSheet) {
            connectPhoneSheet
        }
        .sheet(isPresented: $viewModel.showConnectEmailSheet) {
            connectEmailSheet
        }
    }

    private func listBanner(text: String, isError: Bool) -> some View {
        Text(text)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(isError ? SplickTheme.Colors.error : SplickTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func providerRow(
        kind: ConnectedAccountProviderKind,
        provider: ConnectedProvider,
        linkAction: ConnectedAccountActionButton.Action?,
        unlinkAction: ConnectedAccountActionButton.Action?,
        isLoading: Bool,
        isDisabled: Bool,
        showsDivider: Bool,
        onLink: @escaping () -> Void,
        onUnlink: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: SplickTheme.Spacing.md) {
                ConnectedAccountProviderIcon(kind: kind)

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                    Text(kind.titleKey(languageService))
                        .font(SplickTheme.Typography.body)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Text(
                        provider.isLinked
                            ? (provider.detail ?? languageService.text(.connectedAccountsStatusLinked))
                            : languageService.text(.connectedAccountsStatusNotLinked)
                    )
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(2)
                }

                Spacer(minLength: SplickTheme.Spacing.sm)

                if let unlinkAction {
                    ConnectedAccountActionButton(
                        action: unlinkAction,
                        isLoading: isLoading,
                        isDisabled: isDisabled,
                        accessibilityLabel: languageService.format(
                            .connectedAccountsUnlinkAccessibility,
                            kind.titleKey(languageService)
                        )
                    ) {
                        onUnlink()
                    }
                } else if let linkAction {
                    ConnectedAccountActionButton(
                        action: linkAction,
                        isLoading: isLoading,
                        isDisabled: isDisabled,
                        accessibilityLabel: languageService.format(
                            .connectedAccountsLinkAccessibility,
                            kind.titleKey(languageService)
                        )
                    ) {
                        onLink()
                    }
                } else if provider.isLinked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(SplickTheme.Colors.success)
                        .accessibilityLabel(languageService.text(.connectedAccountsStatusLinked))
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm + 4)

            if showsDivider {
                Divider()
                    .padding(.leading, SplickTheme.Spacing.md + 40 + SplickTheme.Spacing.md)
            }
        }
    }

    private var connectPhoneSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    ConnectAccountSheetHeader(
                        kind: .phone,
                        title: languageService.text(.connectedAccountsConnectPhoneTitle),
                        subtitle: languageService.text(.connectedAccountsPhoneSheetHint)
                    )

                    if let error = viewModel.phoneSheetError {
                        ConnectAccountSheetErrorBanner(message: error)
                    }

                    if !viewModel.hasSentPhoneCode {
                        SplickTextField(
                            languageService.text(.connectedAccountsPhoneField),
                            text: $viewModel.connectPhoneNumber,
                            icon: "phone"
                        )
                        .keyboardType(.phonePad)
                        .transition(.opacity)

                        SplickButton(
                            languageService.text(.connectedAccountsSendCode),
                            style: .secondary,
                            isLoading: viewModel.isRequestingPhoneCode,
                            isDisabled: viewModel.isRequestingPhoneCode
                        ) {
                            Task { await viewModel.requestPhoneConnectCode() }
                        }
                        .transition(.opacity)
                    } else {
                        if let info = viewModel.phoneSheetInfo {
                            Text(info)
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .transition(.opacity)
                        }

                        SplickOtpField(
                            code: $viewModel.connectPhoneOtp,
                            errorMessage: viewModel.phoneSheetOtpError
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        ConnectAccountResendControl(
                            secondsRemaining: viewModel.phoneResendSecondsRemaining,
                            isRequesting: viewModel.isRequestingPhoneCode,
                            resendLabel: languageService.text(.changePasswordResendCode),
                            countdownFormat: { seconds in
                                languageService.format(.changePasswordResendIn, seconds)
                            },
                            onResend: {
                                Task { await viewModel.resendPhoneConnectCode() }
                            }
                        )

                        SplickButton(
                            languageService.text(.connectedAccountsConnectPhone),
                            isLoading: viewModel.isConnectingPhone,
                            isDisabled: viewModel.isConnectingPhone
                                || viewModel.connectPhoneOtp.count != SplickOtpField.defaultLength
                        ) {
                            Task { _ = await viewModel.linkPhone() }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(SplickTheme.Spacing.lg)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: viewModel.hasSentPhoneCode)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        viewModel.showConnectPhoneSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var connectEmailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    ConnectAccountSheetHeader(
                        kind: .email,
                        title: languageService.text(.connectedAccountsConnectEmailTitle),
                        subtitle: viewModel.isPhoneOnlyAccount
                            ? languageService.text(.connectedAccountsEmailSheetPhoneOnlyHint)
                            : languageService.format(
                                .connectedAccountsEmailSheetHint,
                                viewModel.linkEmailAddress
                            )
                    )

                    if let error = viewModel.emailSheetError {
                        ConnectAccountSheetErrorBanner(message: error)
                    }

                    if viewModel.isPhoneOnlyAccount {
                        SplickTextField(
                            languageService.text(.connectedAccountsEmailField),
                            text: $viewModel.connectEmail,
                            icon: "envelope"
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    } else {
                        ConnectAccountReadOnlyField(
                            label: languageService.text(.changePasswordEmailHint),
                            value: viewModel.linkEmailAddress,
                            icon: "envelope.fill"
                        )
                    }

                    if !viewModel.hasSentEmailCode {
                        SplickButton(
                            languageService.text(.changePasswordSendCode),
                            style: .secondary,
                            isLoading: viewModel.isRequestingEmailCode,
                            isDisabled: viewModel.isRequestingEmailCode
                        ) {
                            Task { await viewModel.requestEmailConnectCode() }
                        }
                        .transition(.opacity)
                    } else {
                        if let info = viewModel.emailSheetInfo {
                            Text(info)
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .transition(.opacity)
                        }

                        SplickOtpField(
                            code: $viewModel.connectEmailOtp,
                            errorMessage: viewModel.emailSheetOtpError
                        )
                        .onChange(of: viewModel.connectEmailOtp) { _ in
                            viewModel.emailSheetOtpError = nil
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        ConnectAccountResendControl(
                            secondsRemaining: viewModel.emailResendSecondsRemaining,
                            isRequesting: viewModel.isRequestingEmailCode,
                            resendLabel: languageService.text(.changePasswordResendCode),
                            countdownFormat: { seconds in
                                languageService.format(.changePasswordResendIn, seconds)
                            },
                            onResend: {
                                Task { await viewModel.resendEmailConnectCode() }
                            }
                        )

                        SplickTextField(
                            languageService.text(.connectedAccountsPasswordField),
                            text: $viewModel.connectEmailPassword,
                            isSecure: true,
                            errorMessage: viewModel.emailSheetPasswordError,
                            icon: "lock",
                            showsPasswordVisibilityToggle: true,
                            isPasswordVisible: $isEmailPasswordVisible,
                            passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                            passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
                        )
                        .textContentType(.newPassword)
                        .onChange(of: viewModel.connectEmailPassword) { _ in
                            viewModel.validateEmailPasswordFields()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        SplickTextField(
                            languageService.text(.connectedAccountsConfirmPasswordField),
                            text: $viewModel.connectEmailConfirm,
                            isSecure: true,
                            errorMessage: viewModel.emailSheetConfirmPasswordError,
                            icon: "lock.fill",
                            showsPasswordVisibilityToggle: true,
                            isPasswordVisible: $isEmailConfirmPasswordVisible,
                            passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                            passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
                        )
                        .textContentType(.newPassword)
                        .onChange(of: viewModel.connectEmailConfirm) { _ in
                            viewModel.validateEmailPasswordFields()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        SplickButton(
                            languageService.text(.connectedAccountsConnectEmail),
                            isLoading: viewModel.isConnectingEmail,
                            isDisabled: viewModel.isConnectingEmail
                                || viewModel.connectEmailOtp.count != SplickOtpField.defaultLength
                        ) {
                            Task { _ = await viewModel.linkEmail() }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(SplickTheme.Spacing.lg)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: viewModel.hasSentEmailCode)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        viewModel.showConnectEmailSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var unlinkGoogleSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    ConnectAccountSheetHeader(
                        kind: .google,
                        title: languageService.text(.connectedAccountsUnlinkGoogleTitle),
                        subtitle: languageService.text(.connectedAccountsUnlinkGoogleHint)
                    )

                    if let error = viewModel.unlinkSheetError {
                        ConnectAccountSheetErrorBanner(message: error)
                    }

                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                        Text(languageService.text(.connectedAccountsVerifyWith))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .padding(.leading, SplickTheme.Spacing.sm)

                        Picker("", selection: $viewModel.unlinkMethod) {
                            Text(languageService.text(.connectedAccountsVerifyPassword))
                                .tag(ConnectedAccountsViewModel.VerificationMethod.password)
                            Text(languageService.text(.connectedAccountsVerifyEmailCode))
                                .tag(ConnectedAccountsViewModel.VerificationMethod.emailCode)
                        }
                        .pickerStyle(.segmented)
                    }

                    switch viewModel.unlinkMethod {
                    case .password:
                        SplickTextField(
                            languageService.text(.connectedAccountsPasswordField),
                            text: $viewModel.unlinkPassword,
                            isSecure: true,
                            errorMessage: viewModel.unlinkSheetPasswordError,
                            icon: "lock",
                            showsPasswordVisibilityToggle: true,
                            isPasswordVisible: $isUnlinkPasswordVisible,
                            passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                            passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
                        )
                        .textContentType(.password)
                        .onChange(of: viewModel.unlinkPassword) { _ in
                            viewModel.unlinkSheetPasswordError = nil
                        }
                    case .emailCode:
                        if !viewModel.hasSentUnlinkCode {
                            SplickButton(
                                languageService.text(.changePasswordSendCode),
                                style: .secondary,
                                isLoading: viewModel.isRequestingUnlinkCode,
                                isDisabled: viewModel.isRequestingUnlinkCode
                            ) {
                                Task { await viewModel.requestUnlinkCode() }
                            }
                        } else {
                            if let info = viewModel.unlinkSheetInfo {
                                Text(info)
                                    .font(SplickTheme.Typography.caption)
                                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }

                            SplickOtpField(
                                code: $viewModel.unlinkOtpCode,
                                errorMessage: viewModel.unlinkSheetOtpError
                            )

                            ConnectAccountResendControl(
                                secondsRemaining: viewModel.unlinkResendSecondsRemaining,
                                isRequesting: viewModel.isRequestingUnlinkCode,
                                resendLabel: languageService.text(.changePasswordResendCode),
                                countdownFormat: { seconds in
                                    languageService.format(.changePasswordResendIn, seconds)
                                },
                                onResend: {
                                    Task { await viewModel.resendUnlinkCode() }
                                }
                            )
                        }
                    }

                    SplickButton(
                        languageService.text(.connectedAccountsUnlinkGoogle),
                        style: .destructive,
                        isLoading: viewModel.isUnlinkingGoogle
                    ) {
                        Task { _ = await viewModel.unlinkGoogle() }
                    }
                }
                .padding(SplickTheme.Spacing.lg)
                .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.unlinkMethod)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: viewModel.hasSentUnlinkCode)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        viewModel.showUnlinkSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
