import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published var showRegistration = false

    private let loginUseCase: LoginUseCaseProtocol

    public init(loginUseCase: LoginUseCaseProtocol) {
        self.loginUseCase = loginUseCase
    }

    func login() async {
        guard validate() else { return }

        state = .loading
        do {
            let session = try await loginUseCase.execute(
                email: email.trimmed,
                password: password
            )
            state = .loaded(session)
            Log.info("Login successful for \(session.user.username)", category: .auth)
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
            Log.error("Login failed: \(error)", category: .auth)
        } catch let error as AuthError {
            state = .failed(error.userMessage)
            Log.error("Login auth error: \(error)", category: .auth)
        } catch {
            state = .failed("An unexpected error occurred.")
            Log.error(error, category: .auth)
        }
    }

    private func validate() -> Bool {
        var isValid = true
        emailError = nil
        passwordError = nil

        if email.trimmed.isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if !email.trimmed.isValidEmail {
            emailError = "Please enter a valid email"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        } else if password.count < AppConstants.Validation.minPasswordLength {
            passwordError = "Password must be at least \(AppConstants.Validation.minPasswordLength) characters"
            isValid = false
        }

        return isValid
    }
}
