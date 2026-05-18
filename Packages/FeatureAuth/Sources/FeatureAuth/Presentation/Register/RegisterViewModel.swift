import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class RegisterViewModel: ObservableObject {
    @Published var email = ""
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var emailError: String?
    @Published var usernameError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var state: LoadingState<AuthSession> = .idle

    private let registerUseCase: RegisterUseCaseProtocol

    public init(registerUseCase: RegisterUseCaseProtocol) {
        self.registerUseCase = registerUseCase
    }

    func register() async {
        guard AppConstants.Dev.useMockData || validate() else { return }

        state = .loading
        do {
            let session = try await registerUseCase.execute(
                email: email.trimmed,
                username: username.trimmed,
                password: password
            )
            state = .loaded(session)
            Log.info("Registration successful for \(session.user.username)", category: .auth)
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch let error as AuthError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("An unexpected error occurred.")
            Log.error(error, category: .auth)
        }
    }

    private func validate() -> Bool {
        var isValid = true
        emailError = nil
        usernameError = nil
        passwordError = nil
        confirmPasswordError = nil

        if email.trimmed.isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if !email.trimmed.isValidEmail {
            emailError = "Please enter a valid email"
            isValid = false
        }

        if username.trimmed.isEmpty {
            usernameError = "Username is required"
            isValid = false
        } else if username.trimmed.count > AppConstants.Validation.maxUsernameLength {
            usernameError = "Username is too long"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        } else if password.count < AppConstants.Validation.minPasswordLength {
            passwordError = "Password must be at least \(AppConstants.Validation.minPasswordLength) characters"
            isValid = false
        }

        if confirmPassword != password {
            confirmPasswordError = "Passwords don't match"
            isValid = false
        }

        return isValid
    }
}
