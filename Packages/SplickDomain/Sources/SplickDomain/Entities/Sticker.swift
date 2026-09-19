import Foundation

public enum StickerSource: Equatable, Sendable {
    case klipy
    case custom(groupId: UUID)
}

public struct Sticker: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let previewURL: URL?
    public let source: StickerSource
    public let width: Int?
    public let height: Int?
    /// Server-side favorite row id when loaded from or saved to favorites API.
    public let favoriteId: UUID?

    public init(
        id: String,
        url: URL,
        previewURL: URL? = nil,
        source: StickerSource,
        width: Int? = nil,
        height: Int? = nil,
        favoriteId: UUID? = nil
    ) {
        self.id = id
        self.url = url
        self.previewURL = previewURL
        self.source = source
        self.width = width
        self.height = height
        self.favoriteId = favoriteId
    }

    public func withFavoriteId(_ favoriteId: UUID?) -> Sticker {
        Sticker(
            id: id,
            url: url,
            previewURL: previewURL,
            source: source,
            width: width,
            height: height,
            favoriteId: favoriteId
        )
    }
}
