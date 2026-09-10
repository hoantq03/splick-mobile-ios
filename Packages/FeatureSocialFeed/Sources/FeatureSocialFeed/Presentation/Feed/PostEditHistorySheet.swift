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
                    ProgressView()
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
                                PostEditHistoryCell(item: item)
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.top, SplickTheme.Spacing.sm)
                        .padding(.bottom, SplickTheme.Spacing.lg)
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
                currentAt: post.editedAt ?? post.createdAt
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
            Text(changeLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
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

    private var changeLabel: String {
        switch item.change {
        case .original:
            languageService.text(.feedPostEditHistoryOriginal)
        case .caption:
            languageService.text(.feedPostEditHistoryChangeCaption)
        case .media:
            languageService.text(.feedPostEditHistoryChangePhotos)
        case .captionAndMedia:
            languageService.text(.feedPostEditHistoryChangeCaptionAndPhotos)
        }
    }
}
