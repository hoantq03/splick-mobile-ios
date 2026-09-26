import Foundation

extension URLSession {
    /// Shared session for API calls — bounded timeouts so pull-to-refresh cannot hang indefinitely.
    public static let splick: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 6
        // Authenticated JSON must not be reused from NSURLCache. A cached GET /v1/feed
        // would bring a just-deleted post back on the next reload.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
}
