import Foundation

public class DefaultNotificationRepository: NotificationRepository {
    private let baseURL = URL(string: "http://localhost:8080/api/v1/notifications")!
    private let tokenProvider: () async -> String?
    
    public init(tokenProvider: @escaping () async -> String? = { nil }) {
        self.tokenProvider = tokenProvider
    }
    
    public func getNotifications(page: Int, limit: Int) async throws -> [NotificationItem] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(limit))
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        // Inject the Auth Token here
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await tokenProvider() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            // Fallback for mock/local if no token provider is setup yet
            request.addValue("00000000-0000-0000-0000-000000000001", forHTTPHeaderField: "X-User-Id")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Assuming Spring Data Page<T> format: {"content": [...], "pageable": {...}, ...}
        struct SpringPageInfo: Codable {
            let content: [NotificationItem]
        }
        
        let decoder = JSONDecoder()
        // Spring Boot usually returns ISO 8601 strings
        decoder.dateDecodingStrategy = .iso8601
        
        let pageResult = try decoder.decode(SpringPageInfo.self, from: data)
        return pageResult.content
    }
    
    public func markAsClicked(id: UUID) async throws {
        let url = baseURL.appendingPathComponent(id.uuidString).appendingPathComponent("click")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = await tokenProvider() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.addValue("00000000-0000-0000-0000-000000000001", forHTTPHeaderField: "X-User-Id") // Mock Auth
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
