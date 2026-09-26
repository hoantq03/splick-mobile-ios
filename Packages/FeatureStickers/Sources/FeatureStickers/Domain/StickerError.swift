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
            return "KLIPY chưa được cấu hình. Thêm KLIPY_API_KEY vào .env rồi chạy make generate."
        case .rateLimitExceeded:
            return "Đã hết hạn mức KLIPY hôm nay. Thử lại sau hoặc dùng sticker nhóm."
        case .groupRequired:
            return "Chọn nhóm để xem sticker tùy chỉnh."
        case .network(let message):
            return message
        }
    }
}
