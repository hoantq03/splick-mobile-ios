import Foundation

/// Matches backend {@code X-Request-Id} / Kong correlation-id header.
public enum APIRequestCorrelation {
    public static let headerName = "X-Request-Id"
}
