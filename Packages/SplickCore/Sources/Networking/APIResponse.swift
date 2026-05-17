import Foundation

public struct APIResponse<T: Decodable>: Decodable {
    public let data: T
    public let message: String?
    public let timestamp: String?

    public init(data: T, message: String? = nil, timestamp: String? = nil) {
        self.data = data
        self.message = message
        self.timestamp = timestamp
    }
}

public struct PaginatedResponse<T: Decodable>: Decodable {
    public let items: [T]
    public let page: Int
    public let totalPages: Int
    public let totalItems: Int
    public let hasNext: Bool

    public init(items: [T], page: Int, totalPages: Int, totalItems: Int, hasNext: Bool) {
        self.items = items
        self.page = page
        self.totalPages = totalPages
        self.totalItems = totalItems
        self.hasNext = hasNext
    }
}

public struct EmptyResponse: Decodable {}
