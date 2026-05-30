import SwiftUI
import Nuke
import NukeUI

/// Square grid thumbnail backed by Nuke disk + memory cache.
/// Uses a downscaled request so album grids decode faster and reuse cache entries.
public struct GridThumbnailImage<Placeholder: View>: View {
    private let url: URL?
    private let thumbnailWidth: CGFloat
    private let placeholder: () -> Placeholder

    public init(
        url: URL?,
        thumbnailWidth: CGFloat = 300,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.thumbnailWidth = thumbnailWidth
        self.placeholder = placeholder
    }

    public var body: some View {
        LazyImage(request: imageRequest) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
                    .overlay {
                        if state.isLoading {
                            SplickSpinner(size: .small)
                        }
                    }
            }
        }
        .onDisappear(.lowerPriority)
    }

    private var imageRequest: ImageRequest? {
        url.map { url in
            ImageRequest(
                url: url,
                processors: [.resize(width: thumbnailWidth)]
            )
        }
    }
}

extension GridThumbnailImage where Placeholder == Color {
    public init(url: URL?, thumbnailWidth: CGFloat = 300) {
        self.init(url: url, thumbnailWidth: thumbnailWidth) {
            Color.clear
        }
    }
}

public enum ImagePrefetching {
    /// Warms Nuke disk/memory cache for upcoming grid cells.
    public static func prefetch(urls: [URL], thumbnailWidth: CGFloat = 300) {
        let requests = urls.map { url in
            ImageRequest(url: url, processors: [.resize(width: thumbnailWidth)])
        }
        guard !requests.isEmpty else { return }
        ImagePrefetcher().startPrefetching(with: requests)
    }
}
