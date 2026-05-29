import UIKit

enum EditorSymbolCategory: String, CaseIterable, Identifiable {
    case popular
    case communication
    case weather
    case nature
    case devices
    case transport
    case sport
    case media
    case commerce
    case health
    case shapes
    case arrows

    var id: String { rawValue }

    var label: String {
        switch self {
        case .popular: return "Phổ biến"
        case .communication: return "Liên lạc"
        case .weather: return "Thời tiết"
        case .nature: return "Thiên nhiên"
        case .devices: return "Thiết bị"
        case .transport: return "Di chuyển"
        case .sport: return "Thể thao"
        case .media: return "Media"
        case .commerce: return "Mua sắm"
        case .health: return "Sức khỏe"
        case .shapes: return "Hình dạng"
        case .arrows: return "Mũi tên"
        }
    }
}

enum EditorSFSymbolCatalog {
    private static let catalog: [EditorSymbolCategory: [String]] = [
        .popular: [
            "heart.fill", "star.fill", "flame.fill", "bolt.fill", "sparkles",
            "hand.thumbsup.fill", "hand.thumbsdown.fill", "face.smiling.fill",
            "camera.fill", "photo.fill", "music.note", "gift.fill", "bell.fill",
            "bookmark.fill", "flag.fill", "crown.fill", "trophy.fill", "medal.fill",
            "checkmark.seal.fill", "xmark.seal.fill", "questionmark.circle.fill",
            "exclamationmark.triangle.fill", "info.circle.fill", "plus.circle.fill",
            "minus.circle.fill", "multiply.circle.fill", "divide.circle.fill",
        ],
        .communication: [
            "message.fill", "bubble.left.fill", "bubble.right.fill", "phone.fill",
            "phone.arrow.up.right.fill", "video.fill", "envelope.fill", "paperplane.fill",
            "megaphone.fill", "quote.bubble.fill", "text.bubble.fill", "captions.bubble.fill",
            "person.fill", "person.2.fill", "person.3.fill", "person.crop.circle.fill",
            "at", "link", "wifi", "antenna.radiowaves.left.and.right",
        ],
        .weather: [
            "sun.max.fill", "moon.fill", "cloud.fill", "cloud.sun.fill", "cloud.moon.fill",
            "cloud.rain.fill", "cloud.bolt.fill", "cloud.snow.fill", "cloud.fog.fill",
            "wind", "tornado", "hurricane", "thermometer.sun.fill", "thermometer.snowflake",
            "umbrella.fill", "snowflake", "drop.fill", "humidity.fill",
        ],
        .nature: [
            "leaf.fill", "tree.fill", "flame.fill", "mountain.2.fill", "water.waves",
            "hare.fill", "tortoise.fill", "ant.fill", "ladybug.fill", "pawprint.fill",
            "fish.fill", "bird.fill", "lizard.fill", "cat.fill", "dog.fill",
            "carrot.fill", "apple.logo", "leaf.arrow.circlepath",
        ],
        .devices: [
            "iphone", "ipad", "laptopcomputer", "desktopcomputer", "applewatch",
            "airpods", "airpodspro", "headphones", "keyboard.fill", "printer.fill",
            "display", "tv.fill", "gamecontroller.fill", "camera.fill", "video.fill",
            "battery.100", "battery.75", "battery.50", "battery.25", "bolt.batteryblock.fill",
            "wifi", "wifi.slash", "cellularbars", "personalhotspot",
        ],
        .transport: [
            "car.fill", "bus.fill", "tram.fill", "bicycle", "scooter",
            "airplane", "ferry.fill", "sailboat.fill", "fuelpump.fill",
            "parkingsign", "location.fill", "location.north.fill", "map.fill",
            "globe.americas.fill", "globe.europe.africa.fill", "globe.asia.australia.fill",
        ],
        .sport: [
            "figure.run", "figure.walk", "figure.hiking", "figure.pool.swim",
            "figure.skiing.downhill", "figure.snowboarding", "figure.surfing",
            "figure.yoga", "figure.strengthtraining.traditional", "sportscourt.fill",
            "soccerball", "basketball.fill", "football.fill", "tennis.racket",
            "dumbbell.fill", "medal.fill", "trophy.fill",
        ],
        .media: [
            "play.fill", "pause.fill", "stop.fill", "forward.fill", "backward.fill",
            "shuffle", "repeat", "music.note", "music.note.list", "music.mic",
            "film.fill", "tv.fill", "photo.fill", "photo.on.rectangle.angled",
            "camera.fill", "video.fill", "mic.fill", "speaker.wave.3.fill",
            "headphones", "radio.fill", "guitars.fill", "pianokeys.fill",
        ],
        .commerce: [
            "cart.fill", "bag.fill", "basket.fill", "creditcard.fill", "banknote.fill",
            "dollarsign.circle.fill", "eurosign.circle.fill", "yensign.circle.fill",
            "tag.fill", "barcode", "qrcode", "storefront.fill", "building.2.fill",
            "gift.fill", "shippingbox.fill", "archivebox.fill",
        ],
        .health: [
            "heart.fill", "heart.text.square.fill", "cross.fill", "cross.case.fill",
            "pills.fill", "syringe.fill", "stethoscope", "brain.head.profile",
            "lungs.fill", "figure.mind.and.body", "bed.double.fill", "moon.zzz.fill",
            "allergens", "medical.thermometer.fill", "bandage.fill",
        ],
        .shapes: [
            "circle.fill", "square.fill", "triangle.fill", "diamond.fill",
            "hexagon.fill", "pentagon.fill", "seal.fill", "capsule.fill",
            "oval.fill", "rhombus.fill", "octagon.fill", "star.fill",
            "heart.fill", "cloud.fill", "shield.fill",
        ],
        .arrows: [
            "arrow.up", "arrow.down", "arrow.left", "arrow.right",
            "arrow.up.circle.fill", "arrow.down.circle.fill", "arrow.left.circle.fill", "arrow.right.circle.fill",
            "arrow.clockwise", "arrow.counterclockwise", "arrow.uturn.left", "arrow.uturn.right",
            "chevron.up", "chevron.down", "chevron.left", "chevron.right",
            "arrow.triangle.2.circlepath", "arrow.triangle.branch",
        ],
    ]

    private static let allRawNames: [String] = {
        Array(Set(catalog.values.flatMap { $0 })).sorted()
    }()

    private static let availableNames: [String] = {
        allRawNames.filter { UIImage(systemName: $0) != nil }
    }()

    static var deviceSymbolCount: Int { availableNames.count }

    static func symbols(in category: EditorSymbolCategory) -> [String] {
        let names = catalog[category] ?? []
        return names.filter { UIImage(systemName: $0) != nil }
    }

    static func search(_ query: String, in category: EditorSymbolCategory?) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pool: [String]
        if let category {
            pool = symbols(in: category)
        } else {
            pool = availableNames
        }
        guard !trimmed.isEmpty else { return pool }
        return pool.filter { $0.lowercased().contains(trimmed) }
    }

    static func tint(for name: String) -> UIColor {
        let palette: [UIColor] = [
            .white, .systemPink, .systemRed, .systemOrange, .systemYellow,
            .systemGreen, .systemTeal, .systemBlue, .systemIndigo, .systemPurple,
        ]
        let index = abs(name.hashValue) % palette.count
        return palette[index]
    }
}
