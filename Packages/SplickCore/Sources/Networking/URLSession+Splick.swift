import Foundation

extension URLSession {
    /// Shared session for API calls — bounded timeouts so pull-to-refresh cannot hang indefinitely.
    public static let splick: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()
}
