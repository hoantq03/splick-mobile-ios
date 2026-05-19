import SwiftUI
import DesignSystem
import Common

public struct AccountSecurityView: View {
    @State private var method: VerificationMethod = .password
    @State private var currentPassword = ""
    @State private var otpCode = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isProcessing = false
    @State private var showDeactivateConfirm = false
    @State private var showDeleteConfirm = false

    public enum VerificationMethod: String, CaseIterable {
        case password = "Password"
        case emailCode = "Email code"
    }

    private let accountEmail: String
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let deactivateAccountUseCase: DeactivateAccountUseCaseProtocol
    private let deleteAccountUseCase: DeleteAccountUseCaseProtocol
    private let onAccountClosed: () -> Void

    public init(
        accountEmail: String,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        deactivateAccountUseCase: DeactivateAccountUseCaseProtocol,
        deleteAccountUseCase: DeleteAccountUseCaseProtocol,
        onAccountClosed: @escaping () -> Void
    ) {
        self.accountEmail = accountEmail
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.deactivateAccountUseCase = deactivateAccountUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.onAccountClosed = onAccountClosed
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                Text("Verify your identity before deactivating or deleting your account.")
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                Picker("Verify with", selection: $method) {
                    ForEach(VerificationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                switch method {
                case .password:
                    SplickTextField("Password", text: $currentPassword, isSecure: true, icon: "lock")
                case .emailCode:
                    SplickButton("Send code to email", style: .secondary) {
                        Task { await sendCode() }
                    }
                    SplickTextField("Verification code", text: $otpCode, icon: "number")
                        .keyboardType(.numberPad)
                }

                if let infoMessage {
                    Text(infoMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                }

                SplickButton("Deactivate account", style: .secondary, isLoading: isProcessing) {
                    showDeactivateConfirm = true
                }

                SplickButton("Delete account", style: .destructive, isLoading: isProcessing) {
                    showDeleteConfirm = true
                }
            }
            .padding()
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Deactivate your account?",
            isPresented: $showDeactivateConfirm,
            titleVisibility: .visible
        ) {
            Button("Deactivate", role: .destructive) {
                Task { await deactivate() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be signed out and unable to sign in until support reactivates the.")
        }
        .confirmationDialog(
            "Delete your account permanently?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your profile data and signs you out on all devices.")
        }
    }

    private func credentials() -> (String?, String?) {
        switch method {
        case .password:
            return (currentPassword, nil)
        case .emailCode:
            return (nil, otpCode)
        }
    }

    private func sendCode() async {
        errorMessage = nil
        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            infoMessage = "Verification code sent to \(accountEmail)."
        } catch let error as AuthError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Could not send verification code."
        }
    }

    private func deactivate() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        let (password, otp) = credentials()
        do {
            try await deactivateAccountUseCase.execute(currentPassword: password, otpCode: otp)
            onAccountClosed()
        } catch let error as AuthError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Could not deactivate account."
        }
    }

    private func deleteAccount() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        let (password, otp) = credentials()
        do {
            try await deleteAccountUseCase.execute(currentPassword: password, otpCode: otp)
            onAccountClosed()
        } catch let error as AuthError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Could not delete account."
        }
    }
}
