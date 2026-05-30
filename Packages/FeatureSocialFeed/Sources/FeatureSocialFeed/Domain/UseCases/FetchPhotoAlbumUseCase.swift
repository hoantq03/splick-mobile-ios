import Foundation
import SplickDomain

public protocol FetchPhotoAlbumUseCaseProtocol: Sendable {
    func execute(page: Int) async throws -> [AlbumPhoto]
}

public final class FetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol
    private let pageSize: Int

    public init(repository: FeedRepositoryProtocol, pageSize: Int = 50) {
        self.repository = repository
        self.pageSize = pageSize
    }

    public func execute(page: Int) async throws -> [AlbumPhoto] {
        try await repository.fetchPhotoAlbum(page: page, limit: pageSize)
    }
}
