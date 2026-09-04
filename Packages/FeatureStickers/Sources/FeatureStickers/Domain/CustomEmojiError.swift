import Foundation
import SplickDomain

public enum CustomEmojiError: Error, LocalizedError {
    case invalidResponse
    case invalidShortcode
    case imageProcessingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid custom emoji response"
        case .invalidShortcode:
            return "Shortcode must be 1-30 lowercase letters, digits, or underscores"
        case .imageProcessingFailed:
            return "Could not process the selected image"
        }
    }
}
