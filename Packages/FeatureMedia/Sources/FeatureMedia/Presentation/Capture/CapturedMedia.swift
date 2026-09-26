import Localization
import UIKit

public enum CapturedMedia: Equatable {
    case image(UIImage, initialFilter: FilterPreset = .none)
    case images([UIImage])
    case video(URL)
    /// Hold-to-record / boomerang frames — compose encodes in the background.
    case pendingVideo(PendingCapturedVideo)
    /// Mixed library selection (photos and/or videos).
    case mixed(images: [UIImage], videos: [URL])

    public static func == (lhs: CapturedMedia, rhs: CapturedMedia) -> Bool {
        switch (lhs, rhs) {
        case (.image(let a, let af), .image(let b, let bf)):
            return a === b && af == bf
        case (.images(let a), .images(let b)):
            return a.elementsEqual(b, by: ===)
        case (.video(let a), .video(let b)):
            return a == b
        case (.pendingVideo(let a), .pendingVideo(let b)):
            return a.id == b.id
        case (.mixed(let ai, let av), .mixed(let bi, let bv)):
            return ai.elementsEqual(bi, by: ===) && av == bv
        default:
            return false
        }
    }

    @MainActor
    public func mediaTypeLabel(using languageService: LanguageService) -> String {
        switch self {
        case .image, .images: return languageService.text(.mediaTypePhoto)
        case .video, .pendingVideo: return languageService.text(.mediaTypeVideo)
        case .mixed: return languageService.text(.mediaTypeVideo)
        }
    }
}
