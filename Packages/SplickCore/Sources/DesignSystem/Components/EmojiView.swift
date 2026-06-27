import SwiftUI
import NukeUI
import Common
import SplickDomain

public struct EmojiView: View {
    private let value: String
    private let size: CGFloat
    @EnvironmentObject private var emojiStore: CustomEmojiStore

    /// Matches the visual diameter of unicode glyphs (`size * 0.85` font in a `size` frame).
    private var glyphDiameter: CGFloat { size * 0.85 }

    public init(value: String, size: CGFloat) {
        self.value = value
        self.size = size
    }

    public var body: some View {
        switch EmojiKind.from(value) {
        case .unicode(let symbol):
            Text(symbol)
                .font(.system(size: glyphDiameter))
                .frame(width: size, height: size)

        case .custom(let shortcode):
            if let url = emojiStore.resolve(shortcode: shortcode) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder(shortcode: shortcode)
                    }
                }
                .frame(width: glyphDiameter, height: glyphDiameter)
                .clipShape(Circle())
                .frame(width: size, height: size)
            } else {
                placeholder(shortcode: shortcode)
            }
        }
    }

    private func placeholder(shortcode: String) -> some View {
        Text(":\(shortcode):")
            .font(.system(size: max(size * 0.35, 8), weight: .medium, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: size, height: size)
    }
}
