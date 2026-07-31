import SwiftUI

/// Feed initial-load skeleton that mirrors post card layout instead of a centered spinner.
public struct FeedSkeletonLoadingView: View {
    private let cardCount: Int

    public init(cardCount: Int = 3) {
        self.cardCount = max(cardCount, 1)
    }

    public var body: some View {
        SkeletonShimmerHost {
            VStack(spacing: SplickTheme.Spacing.md) {
                ForEach(0..<cardCount, id: \.self) { index in
                    FeedPostCardSkeleton(variant: index % 3)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

/// Single post-card-shaped skeleton used by `FeedSkeletonLoadingView` and load-more footers.
public struct FeedPostCardSkeleton: View {
    /// Slight layout variation so stacked cards do not look identical.
    private let variant: Int

    public init(variant: Int = 0) {
        self.variant = variant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            header
            captionLines
            mediaBlock
            reactionRow
            commentPreview
        }
        .splickCard()
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            SkeletonBone.avatar()

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                SkeletonBone(
                    width: nameWidth,
                    height: 14,
                    shape: .rectangle(cornerRadius: Self.lineCornerRadius)
                )
                SkeletonBone(
                    width: 56,
                    height: 10,
                    shape: .rectangle(cornerRadius: Self.lineCornerRadius)
                )
            }

            Spacer(minLength: 0)

            SkeletonBone(
                width: 28,
                height: 10,
                shape: .rectangle(cornerRadius: Self.lineCornerRadius)
            )
        }
    }

    private var captionLines: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            SkeletonBone(height: 12, shape: .rectangle(cornerRadius: Self.lineCornerRadius))
            if variant != 1 {
                SkeletonBone(
                    width: captionSecondLineWidth,
                    height: 12,
                    shape: .rectangle(cornerRadius: Self.lineCornerRadius)
                )
            }
        }
    }

    private var mediaBlock: some View {
        SkeletonBone(
            height: mediaHeight,
            shape: .rectangle(cornerRadius: FeedMediaLayout.cornerRadius)
        )
    }

    private var reactionRow: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonBone(
                    width: 36,
                    height: 28,
                    shape: .rectangle(cornerRadius: SplickTheme.CornerRadius.pill)
                )
            }
            Spacer(minLength: 0)
            SkeletonBone(
                width: 48,
                height: 12,
                shape: .rectangle(cornerRadius: Self.lineCornerRadius)
            )
        }
    }

    private var commentPreview: some View {
        SkeletonBone(
            width: commentPreviewWidth,
            height: 12,
            shape: .rectangle(cornerRadius: Self.lineCornerRadius)
        )
        .padding(.top, SplickTheme.Spacing.xxxs)
    }

    private static let lineCornerRadius: CGFloat = 4

    private var nameWidth: CGFloat {
        switch variant % 3 {
        case 0: return 110
        case 1: return 88
        default: return 132
        }
    }

    private var captionSecondLineWidth: CGFloat {
        variant % 2 == 0 ? 180 : 140
    }

    private var commentPreviewWidth: CGFloat {
        variant % 2 == 0 ? 160 : 120
    }

    private var mediaHeight: CGFloat {
        switch variant % 3 {
        case 0: return FeedMediaLayout.placeholderHeight
        case 1: return FeedMediaLayout.minHeight
        default: return FeedMediaLayout.defaultHeight * 0.85
        }
    }
}

/// Grid-cell skeleton for album / photo loading states.
public struct FeedAlbumSkeletonLoadingView: View {
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: SplickTheme.Spacing.xs),
        count: 4
    )

    public init() {}

    public var body: some View {
        SkeletonShimmerHost {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                        SkeletonBone(
                            width: 120,
                            height: 16,
                            shape: .rectangle(cornerRadius: 4)
                        )
                        LazyVGrid(columns: columns, spacing: SplickTheme.Spacing.xs) {
                            ForEach(0..<8, id: \.self) { _ in
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        SkeletonBone(
                                            shape: .rectangle(cornerRadius: SplickTheme.CornerRadius.small)
                                        )
                                    }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}
