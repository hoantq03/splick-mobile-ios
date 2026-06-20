import SwiftUI
import Common
import DesignSystem
import SplickDomain

public struct GifPickerView: View {
    @ObservedObject private var viewModel: GifPickerViewModel
    private let onSelect: (Sticker) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 8),
    ]

    public init(viewModel: GifPickerViewModel, onSelect: @escaping (Sticker) -> Void) {
        self.viewModel = viewModel
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            searchBar
            tabPicker
            content
            if viewModel.showsGiphyAttribution {
                giphyAttribution
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .onAppear { viewModel.onAppear() }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            TextField("Tìm GIF...", text: Binding(
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
        viewModel.showsCustomTab ? StickerPickerTab.allCases : [.giphy]
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
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(stickers) { sticker in
                            Button {
                                onSelect(sticker)
                            } label: {
                                AnimatedRemoteImage(url: sticker.previewURL ?? sticker.url)
                                    .frame(height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                                            .stroke(SplickTheme.Colors.divider.opacity(0.6), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private var emptyMessage: String {
        switch viewModel.selectedTab {
        case .giphy:
            return "Thử từ khóa khác hoặc kiểm tra GIPHY_API_KEY."
        case .custom:
            return "Nhóm chưa có sticker tùy chỉnh."
        }
    }

    private var giphyAttribution: some View {
        Link(destination: AppConstants.Giphy.attributionURL) {
            HStack(spacing: 4) {
                Text("Powered by")
                    .font(.system(size: 11))
                Text("GIPHY")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
