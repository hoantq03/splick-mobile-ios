import Foundation

public enum StickerSource: Equatable, Sendable {
    case giphy
    case custom(groupId: UUID)
}

public struct Sticker: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let previewURL: URL?
    public let source: StickerSource
    public let width: Int?
    public let height: Int?

    public init(
        id: String,
        url: URL,
        previewURL: URL? = nil,
        source: StickerSource,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.previewURL = previewURL
        self.source = source
        self.width = width
        self.height = height
    }
}
