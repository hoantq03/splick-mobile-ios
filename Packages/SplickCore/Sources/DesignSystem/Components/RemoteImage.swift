import SwiftUI
import NukeUI

/// Drop-in replacement for `AsyncImage` backed by Nuke memory + disk cache.
/// Nuke is an implementation detail — feature packages import `DesignSystem` only.
public struct RemoteImage<Content: View>: View {
    private let url: URL?
    private let content: (AsyncImagePhase) -> Content

    public init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    public var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                content(.success(image))
            } else if let error = state.error {
                content(.failure(error))
            } else {
                content(.empty)
            }
        }
    }
}
