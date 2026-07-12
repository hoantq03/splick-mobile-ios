import Common
import SwiftUI

/// Inline GIF for comments/chat — loads immediately and auto-plays while mounted.
public struct InlineGifAttachmentView: View {
    public let url: URL
    /// Optional smaller animated source (e.g. KLIPY tinygif).
    public var previewURL: URL?
    public var widthFraction: CGFloat
    /// When set, overrides `widthFraction` (preferred for comment rows).
    public var maxWidth: CGFloat?
    public var cornerRadius: CGFloat

    @State private var isVisible = true
    @State private var pixelAspectRatio: CGFloat = 1

    public init(
        url: URL,
        previewURL: URL? = nil,
        widthFraction: CGFloat = 1.0 / 3.0,
        maxWidth: CGFloat? = nil,
        cornerRadius: CGFloat = 8
    ) {
        self.url = url
        self.previewURL = previewURL
        self.widthFraction = widthFraction
        self.maxWidth = maxWidth
        self.cornerRadius = cornerRadius
    }

    private var targetWidth: CGFloat {
        if let maxWidth, maxWidth > 0 {
            return maxWidth
        }
        return max(UIScreen.main.bounds.width * widthFraction, 1)
    }

    private var targetHeight: CGFloat {
        let ratio = max(pixelAspectRatio, 0.05)
        return targetWidth / ratio
    }

    private var maxPixelSize: CGFloat {
        RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: targetWidth)
    }

    private var playbackURL: URL {
        if let previewURL, previewURL.isLikelyAnimatedImage {
            return previewURL
        }
        return url
    }

    public var body: some View {
        // Fixed box prevents UIViewRepresentable from stretching the comment row.
        Color.clear
            .frame(width: targetWidth, height: targetHeight)
            .overlay {
                AnimatedRemoteImage(
                    url: playbackURL,
                    contentMode: .fit,
                    maxPixelSize: maxPixelSize,
                    isAnimating: isVisible,
                    onPixelSize: { size in
                        guard size.width > 0, size.height > 0 else { return }
                        let next = size.width / size.height
                        if abs(next - pixelAspectRatio) > 0.01 {
                            pixelAspectRatio = next
                        }
                    }
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .fixedSize(horizontal: true, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }
}
