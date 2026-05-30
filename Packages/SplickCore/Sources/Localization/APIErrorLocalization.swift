import Foundation
import Common

public enum APIErrorLocalization {
    public static func message(for error: Error, locale: AppLocale) -> String {
        if let appError = error as? AppError {
            return message(for: appError, locale: locale)
        }
        if let networkError = error as? NetworkError {
            return message(for: networkError, locale: locale)
        }
        if let authError = error as? AuthError {
            return message(for: authError, locale: locale)
        }
        let fallback = error.localizedDescription
        return fallback.isEmpty ? L10n.string(.errorNetworkUnexpected, locale: locale) : fallback
    }

    public static func message(for error: AppError, locale: AppLocale) -> String {
        switch error {
        case .network(let networkError):
            return message(for: networkError, locale: locale)
        case .auth(let authError):
            return message(for: authError, locale: locale)
        case .validation(let message):
            return message
        case .storage(let storageError):
            return storageError.userMessage
        case .unknown(let message):
            return message
        }
    }

    public static func message(for error: NetworkError, locale: AppLocale) -> String {
        switch error {
        case .noConnection:
            return L10n.string(.errorNetworkNoConnection, locale: locale)
        case .serverUnreachable:
            #if DEBUG
            return L10n.string(.errorNetworkServerUnreachableDebug, locale: locale)
            #else
            return L10n.string(.errorNetworkServerUnreachable, locale: locale)
            #endif
        case .timeout:
            return L10n.string(.errorNetworkTimeout, locale: locale)
        case .serverError:
            return L10n.string(.errorNetworkServer, locale: locale)
        case .decodingFailed:
            return L10n.string(.errorNetworkDecoding, locale: locale)
        case .invalidURL:
            return L10n.string(.errorNetworkInvalidURL, locale: locale)
        case .unauthorized:
            return L10n.string(.errorNetworkUnauthorized, locale: locale)
        case .forbidden:
            return L10n.string(.errorNetworkForbidden, locale: locale)
        case .notFound:
            return L10n.string(.errorNetworkNotFound, locale: locale)
        case .rateLimited:
            return L10n.string(.errorNetworkRateLimited, locale: locale)
        case .unknown(let message, _):
            return message.isEmpty
                ? L10n.string(.errorNetworkUnexpected, locale: locale)
                : message
        }
    }

    public static func message(for error: AuthError, locale: AppLocale) -> String {
        switch error {
        case .invalidCredentials:
            return L10n.string(.errorAuthInvalidCredentials, locale: locale)
        case .tokenExpired:
            return L10n.string(.errorAuthTokenExpired, locale: locale)
        case .refreshFailed:
            return L10n.string(.errorAuthRefreshFailed, locale: locale)
        case .accountLocked:
            return L10n.string(.errorAuthAccountLocked, locale: locale)
        case .accountInactive:
            return L10n.string(.errorAuthAccountInactive, locale: locale)
        case .cannotUnlinkLastAuthMethod:
            return L10n.string(.errorAuthCannotUnlinkLast, locale: locale)
        case .googleAlreadyLinked:
            return L10n.string(.errorAuthGoogleAlreadyLinked, locale: locale)
        case .providerAlreadyLinked:
            return L10n.string(.errorAuthProviderAlreadyLinked, locale: locale)
        case .invalidOtp(let message):
            return message.isEmpty
                ? L10n.string(.errorAuthInvalidOtpDefault, locale: locale)
                : message
        case .otpRateLimited:
            return L10n.string(.errorAuthOtpRateLimited, locale: locale)
        case .registrationFailed(let reason):
            return L10n.format(.errorAuthRegistrationFailed, locale: locale, reason)
        case .emailAlreadyExists:
            return L10n.string(.errorAuthEmailExists, locale: locale)
        case .emailUseGoogle:
            return L10n.string(.errorAuthEmailUseGoogle, locale: locale)
        case .phoneAlreadyExists:
            return L10n.string(.errorAuthPhoneExists, locale: locale)
        case .usernameAlreadyExists:
            return L10n.string(.errorAuthUsernameExists, locale: locale)
        }
    }
}
