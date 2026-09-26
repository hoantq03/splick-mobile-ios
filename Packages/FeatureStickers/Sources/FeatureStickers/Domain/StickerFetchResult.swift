import Foundation
import SplickDomain

public struct StickerFetchResult: Sendable, Equatable {
    public let stickers: [Sticker]
    public let nextPosition: String?

    public init(stickers: [Sticker], nextPosition: String? = nil) {
        self.stickers = stickers
        self.nextPosition = nextPosition
    }
}
