import Foundation

extension Error {
    /// True when URLSession or Swift concurrency ended the request intentionally (e.g. pull-to-refresh superseded).
    public var isRequestCancellation: Bool {
        if self is CancellationError {
            return true
        }
        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }
        if let network = self as? NetworkError,
           case .unknown(let message, _) = network,
           message.localizedCaseInsensitiveContains("cancel") {
            return true
        }
        return false
    }
}
