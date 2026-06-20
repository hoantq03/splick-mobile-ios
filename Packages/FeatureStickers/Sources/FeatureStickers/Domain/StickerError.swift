import Foundation
import SplickDomain

public enum StickerError: LocalizedError, Equatable, Sendable {
    case apiKeyMissing
    case rateLimitExceeded
    case groupRequired
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Giphy chưa được cấu hình. Thêm GIPHY_API_KEY vào Info.plist."
        case .rateLimitExceeded:
            return "Đã hết hạn mức Giphy hôm nay. Thử lại sau hoặc dùng sticker nhóm."
        case .groupRequired:
            return "Chọn nhóm để xem sticker tùy chỉnh."
        case .network(let message):
            return message
        }
    }
}
