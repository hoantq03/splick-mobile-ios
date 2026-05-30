import Foundation
import SplickDomain

public protocol FetchPhotoAlbumUseCaseProtocol: Sendable {
    func fetchFirstPage(filters: PhotoAlbumFilters) async throws -> AlbumPhotoPage
    func fetchNextPage(filters: PhotoAlbumFilters, cursor: String) async throws -> AlbumPhotoPage
}

public final class FetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol
    private let pageSize: Int

    public init(repository: FeedRepositoryProtocol, pageSize: Int = 50) {
        self.repository = repository
        self.pageSize = pageSize
    }

    public func fetchFirstPage(filters: PhotoAlbumFilters) async throws -> AlbumPhotoPage {
        try await repository.fetchPhotoAlbumFirstPage(limit: pageSize, filters: filters)
    }

    public func fetchNextPage(filters: PhotoAlbumFilters, cursor: String) async throws -> AlbumPhotoPage {
        try await repository.fetchPhotoAlbumNextPage(limit: pageSize, filters: filters, cursor: cursor)
    }
}
