import Foundation

public struct StickerCategory: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let previewURL: URL?

    public init(id: String, name: String, previewURL: URL? = nil) {
        self.id = id
        self.name = name
        self.previewURL = previewURL
    }
}
