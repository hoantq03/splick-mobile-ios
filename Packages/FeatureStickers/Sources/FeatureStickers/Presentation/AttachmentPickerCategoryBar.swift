import SwiftUI
import DesignSystem
import SplickDomain

struct AttachmentPickerCategoryBar: View {
    let categories: [StickerCategory]
    let showsCustomPack: Bool
    let selectedCategory: AttachmentPickerCategory
    let isSearchActive: Bool
    let options: AttachmentPickerOptions
    let onSelect: (AttachmentPickerCategory) -> Void

    private enum Metrics {
        static let itemSize: CGFloat = 40
        static let spacing: CGFloat = 8
        static let cornerRadius: CGFloat = SplickTheme.CornerRadius.medium
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metrics.spacing) {
                if options.allowsGifSelection {
                    categoryButton(
                        category: .search,
                        isSelected: isSearchActive,
                        accessibilityLabel: "Tìm kiếm"
                    ) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(iconColor(isSelected: isSearchActive))
                    }

                    categoryButton(
                        category: .favorites,
                        isSelected: selectedCategory == .favorites,
                        accessibilityLabel: "Yêu thích"
                    ) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(iconColor(isSelected: selectedCategory == .favorites))
                    }

                    categoryButton(
                        category: .trending,
                        isSelected: selectedCategory == .trending && !isSearchActive,
                        accessibilityLabel: "Đang hot"
                    ) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(iconColor(isSelected: selectedCategory == .trending && !isSearchActive))
                    }
                }

                categoryButton(
                    category: .emoji,
                    isSelected: selectedCategory == .emoji,
                    accessibilityLabel: "Emoji"
                ) {
                    Text("😊")
                        .font(.system(size: 22))
                }

                if options.allowsGifSelection {
                    ForEach(categories) { category in
                        let pickerCategory = AttachmentPickerCategory.klipyPack(category)
                        categoryButton(
                            category: pickerCategory,
                            isSelected: selectedCategory == pickerCategory,
                            accessibilityLabel: category.name
                        ) {
                            packThumbnail(url: category.previewURL, fallback: category.name)
                        }
                    }

                    if showsCustomPack {
                        categoryButton(
                            category: .customPack,
                            isSelected: selectedCategory == .customPack,
                            accessibilityLabel: "Splick Custom"
                        ) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(iconColor(isSelected: selectedCategory == .customPack))
                        }
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.xs)
        }
    }

    private func categoryButton<Label: View>(
        category: AttachmentPickerCategory,
        isSelected: Bool,
        accessibilityLabel: String,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            onSelect(category)
        } label: {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func packThumbnail(url: URL?, fallback: String) -> some View {
        if let url {
            let maxPixelSize = RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: Metrics.itemSize)
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
