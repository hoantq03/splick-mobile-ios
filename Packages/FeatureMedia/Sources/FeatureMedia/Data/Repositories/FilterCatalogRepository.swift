import Foundation
import Networking

public final class FilterCatalogRepository: FilterCatalogRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func listFilters() async throws -> [FilterCatalogItem] {
        let response: FilterCatalogListResponseDTO = try await apiClient.request(FilterCatalogEndpoint.list)
        return try response.items.map(FilterCatalogMapper.map)
    }
}
