import UIKit

public enum CapturedMedia: Equatable {
    case image(UIImage)
    case images([UIImage])
    case video(URL)

    public var mediaTypeLabel: String {
        switch self {
        case .image, .images: return "Ảnh"
        case .video: return "Video"
        }
    }
}
