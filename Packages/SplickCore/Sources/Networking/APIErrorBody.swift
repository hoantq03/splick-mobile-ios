import Foundation

public struct APIErrorBody: Decodable, Sendable {
    public let status: Int
    public let error: String
    public let message: String
    public let traceId: String?

    public init(status: Int, error: String, message: String, traceId: String? = nil) {
        self.status = status
        self.error = error
        self.message = message
        self.traceId = traceId
    }
}

public enum APIRequestCorrelation {
    public static let headerName = "X-Request-Id"
}
