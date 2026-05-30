import Foundation
import SwiftUI
import Common
import SplickDomain
import DesignSystem

@MainActor
public final class PhotoAlbumViewModel: ObservableObject {
    @Published private(set) var photos: [AlbumPhoto] = []
    @Published var state: LoadingState<[AlbumPhoto]> = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isRefreshing = false

    private let fetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol
    private var currentPage = 0
    private var canLoadMore = true
    private var fetchedPages = Set<Int>()
    private var loadTask: Task<Void, Never>?

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
        guard canLoadMore, !isLoadingMore, !isRefreshing else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        guard !fetchedPages.contains(nextPage) else { return }

        do {
            let batch = try await fetchPhotoAlbumUseCase.execute(page: nextPage)
            fetchedPages.insert(nextPage)
            currentPage = nextPage
            canLoadMore = batch.count >= Self.pageSize
            appendUnique(batch)
            state = .loaded(photos)
            prefetchThumbnails(in: batch)
        } catch {
            if !error.isRequestCancellation {
                Log.error(error, category: .feed)
            }
        }
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

        currentPage = 0
        canLoadMore = true
        fetchedPages.removeAll()

        do {
            let batch = try await fetchPhotoAlbumUseCase.execute(page: 0)
            guard !Task.isCancelled else { return }
            fetchedPages.insert(0)
            photos = batch
            canLoadMore = batch.count >= Self.pageSize
            state = .loaded(photos)
            prefetchThumbnails(in: batch)
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
