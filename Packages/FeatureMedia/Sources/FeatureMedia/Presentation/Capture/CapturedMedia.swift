import Localization
import UIKit

public enum CapturedMedia: Equatable {
    case image(UIImage, initialFilter: FilterPreset = .none)
    case images([UIImage])
    case video(URL)
    /// Mixed library selection (photos and/or videos).
    case mixed(images: [UIImage], videos: [URL])

    @MainActor
    public func mediaTypeLabel(using languageService: LanguageService) -> String {
        switch self {
        case .image, .images: return languageService.text(.mediaTypePhoto)
        case .video: return languageService.text(.mediaTypeVideo)
        case .mixed: return languageService.text(.mediaTypeVideo)
        }
    }
}
