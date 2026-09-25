import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct PostEditHistorySheet: View {
    @EnvironmentObject private var languageService: LanguageService
    let post: Post
    let load: () async throws -> [PostEditRevision]
    @State private var items: [PostEditHistoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: SplickTheme.Spacing.sm),
        GridItem(.flexible(), spacing: SplickTheme.Spacing.sm),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SplickSpinner()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .padding()
                } else if items.isEmpty {
                    Text(languageService.text(.feedPostEditHistoryEmpty))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: SplickTheme.Spacing.sm) {
                            ForEach(items) { item in
                                NavigationLink(value: item.version) {
                                    PostEditHistoryCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.top, SplickTheme.Spacing.sm)
                        .padding(.bottom, SplickTheme.Spacing.lg)
                    }
                    .navigationDestination(for: Int.self) { version in
                        if let item = items.first(where: { $0.version == version }) {
                            PostEditHistoryDetailView(item: item)
                        }
                    }
                }
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.feedPostEditHistory))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
            .task { await loadHistory() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func loadHistory() async {
        isLoading = true
        do {
            let previous = try await load()
            items = PostEditHistoryTimeline.items(
                previousNewestFirst: previous,
                currentCaption: post.caption,
                currentMedia: post.displayMediaItems,
                currentAt: post.editedAt ?? post.createdAt,
                currentAudience: post.audience,
                currentCompanions: post.companions
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct PostEditHistoryCell: View {
    @EnvironmentObject private var languageService: LanguageService
    let item: PostEditHistoryItem

    private var cover: PostMediaItem? { item.mediaItems.first }
    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            coverImage
            Text(
                item.isCurrent
                    ? languageService.text(.feedPostEditHistoryCurrent)
                    : languageService.format(.feedPostEditHistoryVersion, item.version)
            )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    item.isCurrent
                        ? SplickTheme.Colors.success
                        : SplickTheme.Colors.textPrimary
                )
                .lineLimit(1)
            Text(item.editedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 11))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .lineLimit(1)
            changeChips
        }
        .padding(SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cellShape.fill(SplickTheme.Colors.cardBackground)
        }
        .overlay {
            cellShape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private var coverImage: some View {
        let mediaShape = RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GridThumbnailImage(url: cover?.thumbnailURL ?? cover?.mediaURL) {
                    SplickTheme.Colors.tertiaryBackground
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if item.mediaItems.count > 1 {
                    Text("\(item.mediaItems.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .padding(6)
                } else if cover?.mediaType == .video {
                    Image(systemName: "play.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .clipShape(mediaShape)
    }

    private var changeChips: some View {
        let labels = chipLabels
        return WrappingHStack(spacing: 4) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(SplickTheme.Colors.tertiaryBackground, in: Capsule())
            }
        }
    }

    private var chipLabels: [String] {
        if item.diff.isOriginal {
            return [languageService.text(.feedPostEditHistoryOriginal)]
        }
        var labels: [String] = []
        if item.diff.captionChanged { labels.append(languageService.text(.feedPostEditHistoryChangeCaption)) }
        if item.diff.mediaChanged { labels.append(languageService.text(.feedPostEditHistoryChangePhotos)) }
        if item.diff.audienceChanged { labels.append(languageService.text(.feedPostEditHistoryChangeAudience)) }
        if item.diff.companionsChanged { labels.append(languageService.text(.feedPostEditHistoryChangeTags)) }
        if labels.isEmpty {
            labels.append(languageService.text(.feedPostEditHistoryChangeMixed))
        }
        return labels
    }
}

private struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        FlexibleChipWrap(spacing: spacing, content: content)
    }
}

private struct FlexibleChipWrap<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    var body: some View {
        FlowLayout(spacing: spacing) {
            content()
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widthUsed: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            widthUsed = max(widthUsed, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : widthUsed, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

private struct PostEditHistoryDetailView: View {
    @EnvironmentObject private var languageService: LanguageService
    let item: PostEditHistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                Text(item.caption?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                     ? item.caption!
                     : "—")
                    .font(SplickTheme.Typography.body)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.mediaItems) { media in
                            GridThumbnailImage(url: media.thumbnailURL ?? media.mediaURL) {
                                SplickTheme.Colors.tertiaryBackground
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                if let audience = item.audience {
                    Text("\(languageService.text(.feedAudienceTitle)): \(audienceLabel(audience))")
                        .font(SplickTheme.Typography.callout)
                }
                if let companions = item.companions, !companions.isEmpty {
                    Text(companions.map(\.displayName).joined(separator: ", "))
                        .font(SplickTheme.Typography.callout)
                }

                if !item.diff.isOriginal {
                    Text(languageService.text(.feedPostEditHistoryWhatChanged))
                        .font(SplickTheme.Typography.headline)
                    diffSection
                }
            }
            .padding(SplickTheme.Spacing.md)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(
            item.isCurrent
                ? languageService.text(.feedPostEditHistoryCurrent)
                : languageService.format(.feedPostEditHistoryVersion, item.version)
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var diffSection: some View {
        let diff = item.diff
        if diff.captionChanged {
            labeled(languageService.text(.feedPostEditHistoryCaptionBefore), diff.previousCaption)
            labeled(languageService.text(.feedPostEditHistoryCaptionAfter), diff.nextCaption)
        }
        if !diff.addedMedia.isEmpty {
            Text(languageService.text(.feedPostEditHistoryPhotosAdded))
                .fontWeight(.medium)
            mediaRow(diff.addedMedia)
        }
        if !diff.removedMedia.isEmpty {
            Text(languageService.text(.feedPostEditHistoryPhotosRemoved))
                .fontWeight(.medium)
            mediaRow(diff.removedMedia)
        }
        if diff.audienceChanged {
            labeled(languageService.text(.feedPostEditHistoryAudienceFrom), diff.previousAudience.map(audienceLabel))
            labeled(languageService.text(.feedPostEditHistoryAudienceTo), diff.nextAudience.map(audienceLabel))
        }
        if !diff.addedCompanions.isEmpty {
            labeled(
                languageService.text(.feedPostEditHistoryTagsAdded),
                diff.addedCompanions.map(\.displayName).joined(separator: ", ")
            )
        }
        if !diff.removedCompanions.isEmpty {
            labeled(
                languageService.text(.feedPostEditHistoryTagsRemoved),
                diff.removedCompanions.map(\.displayName).joined(separator: ", ")
            )
        }
    }

    private func labeled(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).fontWeight(.medium)
            Text((value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? value! : "—")
        }
    }

    private func mediaRow(_ mediaItems: [PostMediaItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mediaItems) { media in
                    GridThumbnailImage(url: media.thumbnailURL ?? media.mediaURL) {
                        SplickTheme.Colors.tertiaryBackground
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func audienceLabel(_ audience: PostAudience) -> String {
        switch audience.mode {
        case .friends:
            languageService.text(.friendsTabFriends)
        case .groups:
            languageService.format(.feedAudienceGroupsCount, audience.allowedGroupIds.count)
        case .specificUsers:
            languageService.format(.feedAudienceUsersCount, audience.allowedUserIds.count)
        case .friendsExcept:
            languageService.format(.feedAudienceFriendsExceptCount, audience.excludedUserIds.count)
        }
    }
}
