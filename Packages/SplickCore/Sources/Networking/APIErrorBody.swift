import Foundation

enum APIErrorBody: Decodable {
    let status: Int
    let error: String
    let message: String
    let traceId: String?
}

enum APIRequestCorrelation {
    static let headerName = "X-Request-Id"
}
