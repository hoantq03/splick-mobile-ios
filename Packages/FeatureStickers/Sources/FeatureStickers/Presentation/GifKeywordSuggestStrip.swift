import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

public struct GifKeywordSuggestStrip: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var controller: GifKeywordSuggestController
    var mentionActive: Bool
    var onSelect: (Sticker) -> Void
    var onSeeMore: (String) -> Void

    private enum Layout {
        static let tile: CGFloat = 72
        static let corner: CGFloat = 14
    }

    public init(
        controller: GifKeywordSuggestController,
        mentionActive: Bool,
        onSelect: @escaping (Sticker) -> Void,
        onSeeMore: @escaping (String) -> Void
    ) {
        self.controller = controller
        self.mentionActive = mentionActive
        self.onSelect = onSelect
        self.onSeeMore = onSeeMore
    }

    public var body: some View {
        if mentionActive || controller.stickers.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        controller.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(SplickTheme.Colors.secondaryBackground))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(languageService.text(.stickersGifSuggestDismissA11y))

                    Spacer()

                    if let keyword = controller.keyword {
                        Button {
                            onSeeMore(keyword)
                        } label: {
                            Text(languageService.text(.stickersGifSuggestSeeMore))
                                .font(SplickTheme.Typography.captionBold)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(controller.stickers) { sticker in
                            Button {
                                controller.recordSelection()
                                onSelect(sticker)
                            } label: {
                                tile(sticker)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func tile(_ sticker: Sticker) -> some View {
        let url = sticker.previewURL ?? sticker.url
        let shape = RoundedRectangle(cornerRadius: Layout.corner, style: .continuous)
        return shape
            .fill(SplickTheme.Colors.secondaryBackground)
            .frame(width: Layout.tile, height: Layout.tile)
            .overlay {
                RemoteImage(url: url, maxPixelSize: nil) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.clear
                    }
                }
                .frame(width: Layout.tile, height: Layout.tile)
            }
            .clipShape(shape)
    }
}
