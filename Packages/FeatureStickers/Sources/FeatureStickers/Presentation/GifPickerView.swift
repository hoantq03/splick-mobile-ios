import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

public struct GifPickerView: View {
    @ObservedObject private var viewModel: GifPickerViewModel
    @EnvironmentObject private var languageService: LanguageService
    private let onSelect: (Sticker) -> Void

    private enum GridLayout {
        static let columnsPerRow = 4
        static let spacing: CGFloat = 10
        static let cornerRadius: CGFloat = SplickTheme.CornerRadius.tile
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: GridLayout.spacing),
            count: GridLayout.columnsPerRow
        )
    }

    public init(viewModel: GifPickerViewModel, onSelect: @escaping (Sticker) -> Void) {
        self.viewModel = viewModel
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            searchBar
            tabPicker
            content
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .onAppear { viewModel.onAppear() }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            TextField(languageService.text(.stickersGifSearchPlaceholder), text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.onSearchTextChanged($0) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
    }

    private var tabPicker: some View {
        Picker("Nguồn sticker", selection: Binding(
            get: { viewModel.selectedTab },
            set: { viewModel.onTabChanged($0) }
        )) {
            ForEach(availableTabs) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var availableTabs: [StickerPickerTab] {
        viewModel.showsCustomTab ? StickerPickerTab.allCases : [.klipy]
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stickersState {
        case .idle, .loading:
            LoadingView()
                .frame(maxWidth: .infinity, minHeight: 220)

        case .failed(let message):
            ErrorView(message: message) {
                viewModel.retry()
            }
            .frame(maxWidth: .infinity, minHeight: 220)

        case .loaded(let stickers):
            if stickers.isEmpty {
                EmptyStateView(
                    icon: "face.smiling",
                    title: "Không có GIF",
                    message: emptyMessage
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: GridLayout.spacing) {
                        ForEach(stickers) { sticker in
                            Button {
                                onSelect(sticker)
                            } label: {
                                gifThumbnail(url: sticker.previewURL ?? sticker.url)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private func gifThumbnail(url: URL) -> some View {
        let shape = RoundedRectangle(cornerRadius: GridLayout.cornerRadius, style: .continuous)

        return shape
            .fill(SplickTheme.Colors.secondaryBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AnimatedRemoteImage(
                    url: url,
                    contentMode: .fill,
                    maxPixelSize: RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: 88)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(SplickTheme.Colors.divider.opacity(0.4), lineWidth: 0.5)
            }
            .contentShape(shape)
    }

    private var emptyMessage: String {
        switch viewModel.selectedTab {
        case .klipy:
            return "Thử từ khóa khác hoặc kiểm tra KLIPY_API_KEY."
        case .custom:
            return "Nhóm chưa có sticker tùy chỉnh."
        }
    }
}
