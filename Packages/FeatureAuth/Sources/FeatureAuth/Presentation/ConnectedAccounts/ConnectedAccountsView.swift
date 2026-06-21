import SwiftUI
import DesignSystem
import SplickDomain

public struct ConnectedAccountsView: View {
    @StateObject private var viewModel: ConnectedAccountsViewModel

    public init(viewModel: @autoclosure @escaping () -> ConnectedAccountsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let accounts = viewModel.accounts {
                    VStack(spacing: 0) {
                        providerRow(
                            title: "Google",
                            provider: accounts.google,
                            actionTitle: accounts.google.isLinked ? "Unlink" : "Connect",
                            isLoading: viewModel.isLinkingGoogle,
                            isDisabled: !viewModel.isGoogleLinkAvailable && !accounts.google.isLinked,
                            showsDivider: true
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
                            actionTitle: accounts.emailPassword.isLinked ? nil : "Connect",
                            isLoading: false,
                            isDisabled: false,
                            showsDivider: true
                        ) {
                            viewModel.showConnectEmailSheet = true
                        }

                        providerRow(
                            title: "Phone",
                            provider: accounts.phone,
                            actionTitle: accounts.phone.isLinked ? nil : "Connect",
                            isLoading: false,
                            isDisabled: false,
                            showsDivider: false
                        ) {
                            viewModel.showConnectPhoneSheet = true
                        }
                    }
                    .background(SplickTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle("Connected accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
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

    @ViewBuilder
    private func providerRow(
        title: String,
        provider: ConnectedProvider,
        actionTitle: String?,
        isLoading: Bool,
        isDisabled: Bool,
        showsDivider: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                    Text(title)
                        .font(SplickTheme.Typography.body)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Text(provider.isLinked ? (provider.detail ?? "Connected") : "Not connected")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                Spacer()
                if let actionTitle {
                    Button(actionTitle, action: action)
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .disabled(isDisabled || isLoading)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm + 2)

            if showsDivider {
                Divider()
                    .padding(.leading, SplickTheme.Spacing.md)
            }
        }
    }

    private var connectPhoneSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    Text("Enter your phone number. We will send a verification code by SMS.")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    SplickTextField("Phone number", text: $viewModel.connectPhoneNumber, icon: "phone")
                        .keyboardType(.phonePad)

                    SplickButton("Send verification code", style: .secondary) {
                        Task { await viewModel.requestPhoneConnectCode() }
                    }

                    SplickOtpField(code: $viewModel.connectPhoneOtp)

                    SplickButton(
                        "Connect phone",
                        isLoading: viewModel.isConnectingPhone,
                        isDisabled: viewModel.connectPhoneOtp.count != SplickOtpField.defaultLength
                    ) {
                        Task { _ = await viewModel.linkPhone() }
                    }
                }
                .padding(SplickTheme.Spacing.lg)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle("Connect phone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showConnectPhoneSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var connectEmailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    if viewModel.isPhoneOnlyAccount {
                        Text("Add an email and password to sign in without SMS.")
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        SplickTextField("Email", text: $viewModel.connectEmail, icon: "envelope")
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    } else {
                        Text("Set a password for \(viewModel.linkEmailAddress). We will email you a verification code.")
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    SplickButton("Send verification code", style: .secondary) {
                        Task { await viewModel.requestEmailConnectCode() }
                    }

                    SplickOtpField(code: $viewModel.connectEmailOtp)

                    SplickTextField("Password", text: $viewModel.connectEmailPassword, isSecure: true, icon: "lock")
                    SplickTextField("Confirm password", text: $viewModel.connectEmailConfirm, isSecure: true, icon: "lock.fill")

                    SplickButton(
                        "Connect email",
                        isLoading: viewModel.isConnectingEmail,
                        isDisabled: viewModel.connectEmailOtp.count != SplickOtpField.defaultLength
                    ) {
                        Task { _ = await viewModel.linkEmail() }
                    }
                }
                .padding(SplickTheme.Spacing.lg)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle("Connect email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showConnectEmailSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var unlinkGoogleSheet: some View {
        NavigationStack {
            ScrollView {
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
                        SplickOtpField(code: $viewModel.unlinkOtpCode)
                    }

                    SplickButton("Unlink Google", style: .destructive, isLoading: viewModel.isUnlinkingGoogle) {
                        Task { _ = await viewModel.unlinkGoogle() }
                    }
                }
                .padding(SplickTheme.Spacing.lg)
            }
            .background(SplickTheme.Colors.background)
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
