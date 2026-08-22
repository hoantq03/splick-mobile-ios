import Localization
import SwiftUI

/// Instagram-style vertical editor tools (right rail).
enum ComposerTool: String, CaseIterable, Identifiable {
    case text
    case sticker
    case audio
    case effects
    case mention
    case draw
    case download
    case more

    var id: String { rawValue }

    var isDisabled: Bool {
        self == .audio
    }

    @MainActor
    func title(using languageService: LanguageService) -> String {
        switch self {
        case .text: return languageService.text(.mediaToolText)
        case .sticker: return languageService.text(.mediaToolSticker)
        case .audio: return languageService.text(.mediaToolAudio)
        case .effects: return languageService.text(.mediaToolEffects)
        case .mention: return languageService.text(.mediaToolMention)
        case .draw: return languageService.text(.mediaToolDraw)
        case .download: return languageService.text(.mediaToolDownload)
        case .more: return languageService.text(.mediaToolMore)
        }
    }

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .audio: return "music.note"
        case .effects: return "sparkles"
        case .mention: return "at"
        case .draw: return "paintbrush"
        case .download: return "arrow.down.to.line"
        case .more: return "ellipsis"
        }
    }
}
