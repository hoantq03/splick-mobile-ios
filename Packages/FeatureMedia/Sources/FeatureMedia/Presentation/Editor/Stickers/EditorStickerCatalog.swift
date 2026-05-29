import SwiftUI
import UIKit

enum EditorStickerCategory: String, CaseIterable, Identifiable {
    case widget
    case icon
    case emoji
    case gif

    var id: String { rawValue }

    var label: String {
        switch self {
        case .widget: return "Widget"
        case .icon: return "Icon"
        case .emoji: return "Emoji"
        case .gif: return "GIF"
        }
    }

    var icon: String {
        switch self {
        case .widget: return "square.grid.2x2"
        case .icon: return "star.fill"
        case .emoji: return "face.smiling"
        case .gif: return "photo.on.rectangle.angled"
        }
    }
}

enum WidgetStickerTemplate: String, CaseIterable, Identifiable, Equatable {
    case weather
    case clock
    case calendar
    case music
    case fitness
    case battery
    case network
    case location
    case reminder
    case countdown
    case storage
    case photos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weather: return "Thời tiết"
        case .clock: return "Giờ"
        case .calendar: return "Lịch"
        case .music: return "Nhạc"
        case .fitness: return "Bước chân"
        case .battery: return "Pin"
        case .network: return "Mạng"
        case .location: return "Vị trí"
        case .reminder: return "Nhắc nhở"
        case .countdown: return "Đếm ngược"
        case .storage: return "Bộ nhớ"
        case .photos: return "Ảnh"
        }
    }
}

enum EditorStickerKind: Equatable {
    case symbol(name: String, tint: UIColor)
    case emoji(String)
    case widget(WidgetStickerTemplate)
    case gif(UUID)
}

struct EditorGifSample: Identifiable, Equatable {
    let id: UUID
    let data: Data

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
    }
}

struct EditorStickerItem: Identifiable, Equatable {
    let id: UUID
    var kind: EditorStickerKind
    var normalizedPosition: CGPoint
    var scale: CGFloat
    var rotation: Angle

    init(
        id: UUID = UUID(),
        kind: EditorStickerKind,
        normalizedPosition: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: CGFloat = 1,
        rotation: Angle = .zero
    ) {
        self.id = id
        self.kind = kind
        self.normalizedPosition = normalizedPosition
        self.scale = scale
        self.rotation = rotation
    }
}

enum EditorStickerCatalog {
    static func makeKind(for template: WidgetStickerTemplate) -> EditorStickerKind {
        .widget(template)
    }
}
