import Foundation
import SwiftUI
import Common
import Localization
import SplickDomain
import DesignSystem

@MainActor
public final class PhotoAlbumViewModel: ObservableObject {
    @Published private(set) var photos: [AlbumPhoto] = []
    @Published private(set) var filters = PhotoAlbumFilters()
    @Published var state: LoadingState<[AlbumPhoto]> = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isRefreshing = false

    private var cachedDaySections: [AlbumPhotoDaySection] = []
    private var cachedDaySectionsPhotoCount = -1
    private var cachedDaySectionsLastId: UUID?
    private var cachedDaySectionsLocale: AppLocale?

    func daySections(languageService: LanguageService) -> [AlbumPhotoDaySection] {
        let lastId = photos.last?.id
        if cachedDaySectionsPhotoCount == photos.count,
           cachedDaySectionsLastId == lastId,
           cachedDaySectionsLocale == languageService.locale {
            return cachedDaySections
        }
        cachedDaySectionsPhotoCount = photos.count
        cachedDaySectionsLastId = lastId
        cachedDaySectionsLocale = languageService.locale
        cachedDaySections = AlbumPhotoSectionBuilder.daySections(
            from: photos,
            todayTitle: languageService.text(.notificationSectionToday),
            yesterdayTitle: languageService.text(.notificationSectionYesterday)
        )
        return cachedDaySections
    }

    var hasActiveFilters: Bool {
        filters.hasAnyFilter
    }

    private let fetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol
    private var nextCursor: String?
    private var loadTask: Task<Void, Never>?
    private var captionSearchTask: Task<Void, Never>?

    private static let pageSize = 50

    public init(fetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol) {
        self.fetchPhotoAlbumUseCase = fetchPhotoAlbumUseCase
    }

    func loadInitialIfNeeded() async {
        guard photos.isEmpty else { return }
        await loadAlbum(isPullToRefresh: false)
    }

    func refresh() async {
        await loadAlbum(isPullToRefresh: true)
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, !isRefreshing else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetchPhotoAlbumUseCase.fetchNextPage(
                filters: filters,
                cursor: cursor
            )
            nextCursor = page.nextCursor
            appendUnique(page.photos)
            state = .loaded(photos)
            prefetchThumbnails(in: page.photos)
        } catch {
            if !error.isRequestCancellation {
                Log.error(error, category: .feed)
            }
        }
    }

    func applyFilters(_ newFilters: PhotoAlbumFilters) async {
        guard newFilters != filters else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            filters = newFilters
        }
        await loadAlbum(isPullToRefresh: false)
    }

    func setCaptionQuery(_ query: String) {
        captionSearchTask?.cancel()
        captionSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            var updated = filters
            updated.captionQuery = query
            guard updated != filters else { return }
            await applyFilters(updated)
        }
    }

    func clearFilters() async {
        await applyFilters(PhotoAlbumFilters())
    }

    private func loadAlbum(isPullToRefresh: Bool) async {
        loadTask?.cancel()
        let task = Task {
            await performLoad(isPullToRefresh: isPullToRefresh)
        }
        loadTask = task
        await task.value
    }

    private func performLoad(isPullToRefresh: Bool) async {
        if isPullToRefresh {
            isRefreshing = true
        } else if photos.isEmpty {
            state = .loading
        }

        defer {
            if isPullToRefresh {
                isRefreshing = false
            }
        }

        nextCursor = nil

        do {
            let page = try await fetchPhotoAlbumUseCase.fetchFirstPage(filters: filters)
            guard !Task.isCancelled else { return }
            photos = page.photos
            nextCursor = page.nextCursor
            state = .loaded(photos)
            prefetchThumbnails(in: page.photos)
        } catch {
            guard !Task.isCancelled else { return }
            if error.isRequestCancellation { return }
            Log.error(error, category: .feed)
            if photos.isEmpty {
                state = .failed(error.localizedDescription)
            } else {
                state = .loaded(photos)
            }
        }
    }

    private func appendUnique(_ batch: [AlbumPhoto]) {
        let existingIds = Set(photos.map(\.id))
        let newItems = batch.filter { !existingIds.contains($0.id) }
        photos.append(contentsOf: newItems)
    }

    private func prefetchThumbnails(in photos: [AlbumPhoto]) {
        let urls = photos.compactMap { $0.thumbnailURL ?? $0.mediaURL }
        ImagePrefetching.prefetch(urls: urls)
    }
}
