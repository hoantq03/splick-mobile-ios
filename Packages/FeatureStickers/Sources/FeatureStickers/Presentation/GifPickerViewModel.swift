import Foundation
import Common
import SplickDomain

public enum StickerPickerTab: String, CaseIterable, Identifiable, Sendable {
    case giphy
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .giphy: return "Giphy Trending"
        case .custom: return "Splick Custom"
        }
    }
}

public typealias GifPickerViewModelFactory = (UUID?) -> GifPickerViewModel

@MainActor
public final class GifPickerViewModel: ObservableObject {
    @Published public var selectedTab: StickerPickerTab = .giphy
    @Published public var searchText = ""
    @Published public var stickersState: LoadingState<[Sticker]> = .idle
    @Published public var errorMessage: String?

    public let groupId: UUID?

    private let fetchStickersUseCase: FetchStickersUseCaseProtocol
    private var searchTask: Task<Void, Never>?

    public init(fetchStickersUseCase: FetchStickersUseCaseProtocol, groupId: UUID?) {
        self.fetchStickersUseCase = fetchStickersUseCase
        self.groupId = groupId
    }

    public var showsCustomTab: Bool { groupId != nil }

    public var showsGiphyAttribution: Bool { selectedTab == .giphy }

    public func onAppear() {
        loadStickers(immediate: true)
    }

    public func onTabChanged(_ tab: StickerPickerTab) {
        selectedTab = tab
        loadStickers(immediate: true)
    }

    public func onSearchTextChanged(_ text: String) {
        searchText = text
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(AppConstants.Giphy.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }
            await loadStickers(immediate: false)
        }
    }

    public func retry() {
        loadStickers(immediate: true)
    }

    private func loadStickers(immediate: Bool) {
        if immediate {
            searchTask?.cancel()
        }

        stickersState = .loading
        errorMessage = nil

        Task {
            do {
                if selectedTab == .custom, groupId == nil {
                    throw StickerError.groupRequired
                }
                let stickers = try await fetchStickersUseCase.execute(
                    query: searchText,
                    source: currentSource
                )
                stickersState = .loaded(stickers)
            } catch let error as StickerError {
                stickersState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            } catch {
                stickersState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    private var currentSource: StickerSource {
        switch selectedTab {
        case .giphy:
            return .giphy
        case .custom:
            guard let groupId else {
                return .giphy
            }
            return .custom(groupId: groupId)
        }
    }
}
