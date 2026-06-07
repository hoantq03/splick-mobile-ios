import SwiftUI

struct FeedContentPager<Feed: View, Album: View>: View {
    @Binding var selection: FeedContentSegment
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var album: () -> Album

    var body: some View {
        if #available(iOS 17.0, *) {
            ModernFeedContentPager(
                selection: $selection,
                feed: feed,
                album: album
            )
        } else {
            legacyPager
        }
    }

    private var legacyPager: some View {
        TabView(selection: $selection) {
            feed()
                .tag(FeedContentSegment.feed)

            album()
                .tag(FeedContentSegment.album)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

@available(iOS 17.0, *)
private struct ModernFeedContentPager<Feed: View, Album: View>: View {
    @Binding var selection: FeedContentSegment
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var album: () -> Album

    @State private var scrollPosition: FeedContentSegment?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                feed()
                    .containerRelativeFrame(.horizontal)
                    .id(FeedContentSegment.feed)

                album()
                    .containerRelativeFrame(.horizontal)
                    .id(FeedContentSegment.album)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .onAppear {
            scrollPosition = selection
        }
        .onChange(of: selection) { newValue in
            guard scrollPosition != newValue else { return }
            scrollPosition = newValue
        }
        .onChange(of: scrollPosition) { newValue in
            guard let newValue, selection != newValue else { return }
            selection = newValue
        }
    }
}
