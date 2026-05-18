import UIKit

public enum CapturedMedia: Equatable {
    case image(UIImage)
    case video(URL)

    public var mediaTypeLabel: String {
        switch self {
        case .image: return "Ảnh"
        case .video: return "Video"
        }
    }
}
