import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct AttachmentPickerCategoryBar: View {
    @EnvironmentObject private var languageService: LanguageService

    let categories: [StickerCategory]
    let showsCustomPack: Bool
    let selectedCategory: AttachmentPickerCategory
    let isSearchActive: Bool
    let options: AttachmentPickerOptions
    let onSelect: (AttachmentPickerCategory) -> Void

    private enum Metrics {
        static let itemSize: CGFloat = 44
        static let spacing: CGFloat = 14
        static let columnWidth: CGFloat = 64
        static let cornerRadius: CGFloat = SplickTheme.CornerRadius.medium
        static let thumbnailInset: CGFloat = 3
        static let labelFontSize: CGFloat = 10
        static let sectionSpacing: CGFloat = 10
        static let headerFontSize: CGFloat = 12
    }

    private var showsHashtagRow: Bool {
        options.allowsGifSelection && (showsCustomPack || !categories.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            section(
                title: languageService.text(.stickersQuickAccess),
                showsHeader: true
            ) {
                quickAccessRow
            }

            if showsHashtagRow {
                section(
                    title: languageService.text(.stickersHashtags),
                    showsHeader: true
                ) {
                    hashtagRow
                }
            }
        }
        .padding(.vertical, SplickTheme.Spacing.sm)
    }

    private var quickAccessRow: some View {
        HStack(alignment: .top, spacing: Metrics.spacing) {
            if options.allowsGifSelection {
                categoryButton(
                    category: .search,
                    title: languageService.text(.stickersSearch),
                    isSelected: isSearchActive
                ) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(iconColor(isSelected: isSearchActive))
                }

                categoryButton(
                    category: .favorites,
                    title: languageService.text(.stickersFavorites),
                    isSelected: selectedCategory == .favorites
                ) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(iconColor(isSelected: selectedCategory == .favorites))
                }

                categoryButton(
                    category: .trending,
                    title: languageService.text(.stickersTrendingTerms),
                    isSelected: selectedCategory == .trending && !isSearchActive
                ) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(
                            iconColor(isSelected: selectedCategory == .trending && !isSearchActive)
                        )
                }
            }

            categoryButton(
                category: .emoji,
                title: languageService.text(.stickersEmoji),
                isSelected: selectedCategory == .emoji
            ) {
                Text("😊")
                    .font(.system(size: 22))
            }
        }
    }

    private var hashtagRow: some View {
        HStack(alignment: .top, spacing: Metrics.spacing) {
            ForEach(categories) { category in
                let pickerCategory = AttachmentPickerCategory.klipyPack(category)
                categoryButton(
                    category: pickerCategory,
                    title: category.name,
                    isSelected: selectedCategory == pickerCategory
                ) {
                    packThumbnail(url: category.previewURL, fallback: category.name)
                }
            }

            if showsCustomPack {
                categoryButton(
                    category: .customPack,
                    title: languageService.text(.stickersCustomPack),
                    isSelected: selectedCategory == .customPack
                ) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(iconColor(isSelected: selectedCategory == .customPack))
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        showsHeader: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsHeader {
                Text(title)
                    .font(.system(size: Metrics.headerFontSize, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .accessibilityAddTraits(.isHeader)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                content()
                    .padding(.horizontal, SplickTheme.Spacing.md)
            }
        }
    }

    private func categoryButton<Label: View>(
        category: AttachmentPickerCategory,
        title: String,
        isSelected: Bool,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            onSelect(category)
        } label: {
            VStack(spacing: 4) {
                label()
                    .frame(width: Metrics.itemSize, height: Metrics.itemSize)
                    .background(
                        RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                            .fill(
                                isSelected
                                    ? SplickTheme.Colors.primaryGradientStart.opacity(0.14)
                                    : SplickTheme.Colors.secondaryBackground
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? SplickTheme.Colors.primaryGradientStart.opacity(0.55)
                                    : SplickTheme.Colors.divider.opacity(0.35),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    }

                Text(title)
                    .font(.system(size: Metrics.labelFontSize, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? SplickTheme.Colors.primaryGradientStart
                            : SplickTheme.Colors.textSecondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: Metrics.columnWidth)
            }
            .frame(width: Metrics.columnWidth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func packThumbnail(url: URL?, fallback: String) -> some View {
        let inner = Metrics.itemSize - (Metrics.thumbnailInset * 2)
        if let url {
            let maxPixelSize = RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: inner)
            RemoteImage(url: url, maxPixelSize: maxPixelSize) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.clear
                }
            }
            .frame(width: inner, height: inner)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius - 2, style: .continuous))
        } else {
            Text(String(fallback.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
    }

    private func iconColor(isSelected: Bool) -> Color {
        isSelected
            ? SplickTheme.Colors.primaryGradientStart
            : SplickTheme.Colors.textSecondary
    }
}
