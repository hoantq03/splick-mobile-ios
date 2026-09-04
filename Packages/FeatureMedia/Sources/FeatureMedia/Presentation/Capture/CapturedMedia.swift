import Localization
import UIKit

public enum CapturedMedia: Equatable {
    case image(UIImage, initialFilter: FilterPreset = .none)
    case images([UIImage])
    case video(URL)

    @MainActor
    public func mediaTypeLabel(using languageService: LanguageService) -> String {
        switch self {
        case .image, .images: return languageService.text(.mediaTypePhoto)
        case .video: return languageService.text(.mediaTypeVideo)
        }
    }
}
