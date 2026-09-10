import Foundation
import SplickDomain

public enum AttachmentPickerCategory: Equatable, Sendable {
    case search
    case favorites
    case trending
    case emoji
    case klipyPack(StickerCategory)
    case customPack
}

extension AttachmentPickerCategory: Identifiable {
    public var id: String {
        switch self {
        case .search:
            return "search"
        case .favorites:
            return "favorites"
        case .trending:
            return "trending"
        case .emoji:
            return "emoji"
        case .klipyPack(let category):
            return "klipy-\(category.id)"
        case .customPack:
            return "custom"
        }
    }
}

public struct AttachmentPickerOptions: Sendable {
    public var allowsGifSelection: Bool

    public init(allowsGifSelection: Bool = true) {
        self.allowsGifSelection = allowsGifSelection
    }
}
