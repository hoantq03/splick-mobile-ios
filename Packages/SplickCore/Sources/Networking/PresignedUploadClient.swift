import Foundation
import Common

public enum PresignedUploadError: Error {
    case invalidURL
    case uploadFailed(statusCode: Int)
}

public protocol PresignedUploadClientProtocol: Sendable {
    func put(data: Data, to presignedURL: String, headers: [String: String]) async throws
}

public final class PresignedUploadClient: PresignedUploadClientProtocol, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func put(data: Data, to presignedURL: String, headers: [String: String]) async throws {
        guard let url = URL(string: presignedURL) else {
            throw PresignedUploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PresignedUploadError.uploadFailed(statusCode: -1)
        }
        guard (200...299).contains(http.statusCode) else {
            Log.error("Presigned PUT failed with status \(http.statusCode)", category: .network)
            throw PresignedUploadError.uploadFailed(statusCode: http.statusCode)
        }
    }
}
