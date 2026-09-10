import Foundation

enum SocialPageFetcher {
    private static let defaultPageSize = 100

    static func fetchAll<T>(
        pageSize: Int = defaultPageSize,
        fetchPage: (Int, Int) async throws -> ([T], SocialPageMetaDTO)
    ) async throws -> [T] {
        var page = 0
        var all: [T] = []
        while true {
            let (content, meta) = try await fetchPage(page, pageSize)
            all.append(contentsOf: content)
            let totalPages = max(meta.totalPages, 1)
            if page + 1 >= totalPages || content.isEmpty {
                break
            }
            page += 1
        }
        return all
    }
}
