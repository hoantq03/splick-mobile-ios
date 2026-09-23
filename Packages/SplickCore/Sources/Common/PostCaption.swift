import Foundation

public enum PostCaption {
    /// Matches backend `posts.caption` VARCHAR(2000) / OpenAPI maxLength.
    public static let maxLength = 2000

    public static func exceedsLimit(_ caption: String?) -> Bool {
        characterCount(caption) > maxLength
    }

    public static func characterCount(_ caption: String?) -> Int {
        (caption ?? "").count
    }

    public static func limited(_ caption: String) -> String {
        guard caption.count > maxLength else { return caption }
        return String(caption.prefix(maxLength))
    }
}

public enum PostUploadRecovery: Equatable, Sendable {
    case retry
    case edit
}

public enum PostUploadFailure {
    public static func recovery(for error: Error) -> PostUploadRecovery {
        if let appError = error as? AppError {
            switch appError {
            case .network(let networkError):
                return recovery(for: networkError)
            case .validation:
                return .edit
            default:
                return .retry
            }
        }
        if let networkError = error as? NetworkError {
            return recovery(for: networkError)
        }
        return .retry
    }

    public static func isCaptionTooLong(_ error: Error) -> Bool {
        let code = apiCode(from: error)?.uppercased()
        if code == "CAPTION_TOO_LONG" {
            return true
        }
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = message.lowercased()
        return lower.contains("caption must be at most")
            || lower.contains("value too long")
            || lower.contains("character varying(2000)")
    }

    private static func recovery(for error: NetworkError) -> PostUploadRecovery {
        switch error {
        case .noConnection, .timeout, .serverUnreachable, .serverError, .rateLimited,
             .decodingFailed, .invalidURL, .unauthorized:
            return .retry
        case .apiError(let code, let message, _):
            return recovery(forCode: code, message: message)
        case .unknown(let message, _):
            if looksLikeClientValidation(message) { return .edit }
            return .retry
        case .forbidden, .notFound:
            return .edit
        }
    }

    private static func recovery(forCode code: String, message: String) -> PostUploadRecovery {
        switch code.uppercased() {
        case "CAPTION_TOO_LONG",
             "VALIDATION_ERROR",
             "VALIDATION_FAILED",
             "INVALID_REQUEST",
             "INVALID_ARGUMENT",
             "CONFLICT":
            return .edit
        default:
            if looksLikeClientValidation(message) { return .edit }
            return .retry
        }
    }

    private static func looksLikeClientValidation(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("too long")
            || lower.contains("maxlength")
            || lower.contains("must be at most")
            || lower.contains("data integrity")
    }

    private static func apiCode(from error: Error) -> String? {
        if case .network(.apiError(let code, _, _)) = error as? AppError {
            return code
        }
        if case .apiError(let code, _, _) = error as? NetworkError {
            return code
        }
        return nil
    }
}
