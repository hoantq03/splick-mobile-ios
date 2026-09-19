import Localization
import SwiftUI

/// Instagram-style vertical editor tools (right rail).
enum ComposerTool: String, CaseIterable, Identifiable {
    case text
    case sticker
    case effects
    case draw
    case download
    case edit

    var id: String { rawValue }

    @MainActor
    func title(using languageService: LanguageService) -> String {
        switch self {
        case .text: return languageService.text(.mediaToolText)
        case .sticker: return languageService.text(.mediaToolSticker)
        case .effects: return languageService.text(.mediaToolEffects)
        case .draw: return languageService.text(.mediaToolDraw)
        case .download: return languageService.text(.mediaToolDownload)
        case .edit: return languageService.text(.mediaToolEdit)
        }
    }

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .effects: return "sparkles"
        case .draw: return "paintbrush"
        case .download: return "arrow.down.to.line"
        case .edit: return "slider.horizontal.3"
        }
    }
}
