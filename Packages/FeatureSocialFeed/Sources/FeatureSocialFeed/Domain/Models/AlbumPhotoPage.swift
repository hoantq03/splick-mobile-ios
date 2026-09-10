import Foundation
import SplickDomain

public struct AlbumPhotoPage: Equatable, Sendable {
    public let photos: [AlbumPhoto]
    public let nextCursor: String?

    public init(photos: [AlbumPhoto], nextCursor: String?) {
        self.photos = photos
        self.nextCursor = nextCursor
    }
}
