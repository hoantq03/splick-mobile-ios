import Foundation

public enum SplickErrorFormatting {
    private static let referencePrefix = "Reference:"

    public static func supportTraceId(for error: Error) -> String? {
        if let appError = error as? AppError {
            return supportTraceId(for: appError)
        }
        if let networkError = error as? NetworkError {
            return networkError.supportTraceId
        }
        return nil
    }

    public static func userMessage(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.userMessage
        }
        if let networkError = error as? NetworkError {
            return networkError.userMessage
        }
        return error.localizedDescription
    }

    public static func appendSupportReference(to message: String, traceId: String?) -> String {
        guard let traceId, !traceId.isEmpty else { return message }
        return "\(message)\n\n\(referencePrefix) \(traceId)"
    }

    private static func supportTraceId(for error: AppError) -> String? {
        switch error {
        case .network(let networkError):
            return networkError.supportTraceId
        default:
            return nil
        }
    }
}
