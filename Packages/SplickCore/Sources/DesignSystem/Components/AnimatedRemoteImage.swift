import SwiftUI
import Nuke
import NukeUI

/// Renders remote animated GIF/WebP via Nuke memory + disk cache.
/// Use in sticker grids and comment previews where motion is expected.
public struct AnimatedRemoteImage: View {
    private let url: URL?
    private let contentMode: ContentMode

    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    public var body: some View {
        LazyImage(request: imageRequest) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if state.error != nil {
                Image(systemName: "photo")
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            } else {
                ProgressView()
            }
        }
    }

    private var imageRequest: ImageRequest? {
        guard let url else { return nil }
        return ImageRequest(url: url, processors: [])
    }
}
