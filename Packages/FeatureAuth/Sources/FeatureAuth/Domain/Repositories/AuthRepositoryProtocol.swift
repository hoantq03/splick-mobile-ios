import Foundation
import SplickDomain

public protocol AuthRepositoryProtocol: Sendable {
    func signInWithGoogle(idToken: String) async throws -> AuthSession
    func login(email: String, password: String) async throws -> AuthSession
    func requestEmailOtp(email: String) async throws
    func requestPhoneOtp(phoneNumber: String) async throws
    func verifyPhoneOtp(phoneNumber: String, otpCode: String) async throws -> AuthSession
    func registerWithEmail(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession
    func registerWithPhone(
        phoneNumber: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession
    func refreshToken(_ refreshToken: String) async throws -> AuthSession
    func forgotPassword(email: String) async throws
    func resetPassword(email: String, otpCode: String, newPassword: String) async throws -> AuthSession
    func changePassword(
        currentPassword: String?,
        otpCode: String?,
        newPassword: String
    ) async throws -> AuthSession
    /// Revokes the current device session on the server when possible, then clears local credentials.
    func logout() async
    func getCurrentUser() async throws -> User
    func updateProfile(displayName: String?, avatarUrl: String?, preferredLocale: String?) async throws -> User
    func listSessions() async throws -> [UserSession]
    func revokeSession(id: UUID) async throws
    func revokeAllSessions() async throws
    func deactivateAccount(currentPassword: String?, otpCode: String?) async throws
    func deleteAccount(currentPassword: String?, otpCode: String?) async throws
    func getConnectedAccounts() async throws -> ConnectedAccounts
    func linkGoogleAccount(idToken: String) async throws
    func unlinkGoogleAccount(currentPassword: String?, otpCode: String?) async throws
    func requestLinkPhoneOtp(phoneNumber: String) async throws
    func linkPhoneAccount(phoneNumber: String, otpCode: String) async throws
    func requestLinkEmailOtp(email: String?) async throws
    func linkEmailAccount(email: String?, otpCode: String, password: String) async throws
}
