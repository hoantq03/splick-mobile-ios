import Foundation

public enum AppError: Error, Equatable {
    case network(NetworkError)
    case storage(StorageError)
    case auth(AuthError)
    case validation(String)
    case unknown(String)

    public var userMessage: String {
        switch self {
        case .network(let error): return error.userMessage
        case .storage(let error): return error.userMessage
        case .auth(let error): return error.userMessage
        case .validation(let message): return message
        case .unknown(let message): return message
        }
    }
}

public enum NetworkError: Error, Equatable {
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case decodingFailed
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverUnreachable
    case unknown(String)

    /// True for errors where retrying after fixing network may succeed (not credential-related).
    public var isConnectivityIssue: Bool {
        switch self {
        case .noConnection, .timeout, .serverUnreachable:
            return true
        default:
            return false
        }
    }

    public var userMessage: String {
        switch self {
        case .noConnection: return "No internet connection. Please check your network."
        case .serverUnreachable:
            #if DEBUG
            return "Cannot reach the API server. In Terminal, run: make -C splick-mobile-ios stubs"
            #else
            return "Cannot reach the server. Please try again later."
            #endif
        case .timeout: return "Request timed out. Please try again."
        case .serverError: return "Something went wrong. Please try again later."
        case .decodingFailed: return "Failed to process server response."
        case .invalidURL: return "Invalid request."
        case .unauthorized: return "Session expired. Please log in again."
        case .forbidden: return "You don't have permission to perform this action."
        case .notFound: return "The requested resource was not found."
        case .rateLimited: return "Too many requests. Please wait a moment."
        case .unknown(let message):
            return message.isEmpty ? "An unexpected error occurred." : message
        }
    }
}

public enum StorageError: Error, Equatable {
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case keychainError(String)
    case migrationFailed

    public var userMessage: String {
        switch self {
        case .saveFailed: return "Failed to save data."
        case .fetchFailed: return "Failed to load data."
        case .deleteFailed: return "Failed to delete data."
        case .keychainError: return "Secure storage error."
        case .migrationFailed: return "Data migration failed."
        }
    }
}

public enum AuthError: Error, Equatable {
    case invalidCredentials
    case tokenExpired
    case refreshFailed
    case accountLocked
    case invalidOtp(String)
    case registrationFailed(String)
    case emailAlreadyExists

    public var userMessage: String {
        switch self {
        case .invalidCredentials: return "Invalid email or password."
        case .tokenExpired: return "Your session has expired. Please log in again."
        case .refreshFailed: return "Failed to refresh session."
        case .accountLocked: return "Your account has been locked."
        case .invalidOtp(let message): return message
        case .registrationFailed(let reason): return "Registration failed: \(reason)"
        case .emailAlreadyExists: return "An account with this email already exists."
        }
    }
}
