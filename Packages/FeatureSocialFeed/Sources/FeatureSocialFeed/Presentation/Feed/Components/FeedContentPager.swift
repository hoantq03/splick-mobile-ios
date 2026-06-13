import SwiftUI

struct FeedContentPager<Feed: View, Album: View, Streak: View>: View {
    @Binding var selection: FeedContentSegment
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var album: () -> Album
    @ViewBuilder var streak: () -> Streak

    var body: some View {
        if #available(iOS 17.0, *) {
            ModernFeedContentPager(
                selection: $selection,
                feed: feed,
                album: album,
                streak: streak
            )
        } else {
            legacyPager
        }
    }

    private var legacyPager: some View {
        TabView(selection: $selection) {
            streak()
                .tag(FeedContentSegment.streak)

            feed()
                .tag(FeedContentSegment.feed)

            album()
                .tag(FeedContentSegment.album)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

@available(iOS 17.0, *)
private struct ModernFeedContentPager<Feed: View, Album: View, Streak: View>: View {
    @Binding var selection: FeedContentSegment
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var album: () -> Album
    @ViewBuilder var streak: () -> Streak

    @State private var scrollPosition: FeedContentSegment?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                streak()
                    .containerRelativeFrame(.horizontal)
                    .id(FeedContentSegment.streak)

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
