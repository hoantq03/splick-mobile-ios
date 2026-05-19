import Foundation
import Common
import SplickDomain

public protocol VerifyPhoneOtpUseCaseProtocol: Sendable {
    func execute(phoneNumber: String, otpCode: String) async throws -> AuthSession
}

public final class VerifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(phoneNumber: String, otpCode: String) async throws -> AuthSession {
        do {
            let session = try await repository.verifyPhoneOtp(phoneNumber: phoneNumber, otpCode: otpCode)
            guard session.user.status.allowsSignIn else {
                throw AuthError.invalidCredentials
            }
            await sessionManager.setSession(session)
            return session
        } catch let error as NetworkError where error.isConnectivityIssue {
            throw error
        } catch {
            throw AuthError.invalidCredentials
        }
    }
}
