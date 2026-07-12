import Foundation
import Common
import SplickDomain

protocol KlipyDataSourceProtocol: Sendable {
    func search(query: String, position: String?) async throws -> StickerFetchResult
    func trending(position: String?) async throws -> StickerFetchResult
    func categories() async throws -> [StickerCategory]
    func autocomplete(query: String) async throws -> [String]
    func searchSuggestions(query: String) async throws -> [String]
    func trendingTerms() async throws -> [String]
    func registerShare(gifId: String, searchQuery: String?) async throws
}

final class KlipyDataSource: KlipyDataSourceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .splick) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func search(query: String, position: String? = nil) async throws -> StickerFetchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await trending(position: position)
        }

        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/search")
        components?.queryItems = stickerQueryItems(position: position) + [
            URLQueryItem(name: "q", value: trimmed),
        ]
        return try await fetchStickerPage(from: components)
    }

    func trending(position: String? = nil) async throws -> StickerFetchResult {
        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/featured")
        components?.queryItems = stickerQueryItems(position: position)
        return try await fetchStickerPage(from: components)
    }

    func categories() async throws -> [StickerCategory] {
        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/categories")
        components?.queryItems = metaQueryItems + [
            URLQueryItem(name: "type", value: "featured"),
        ]
        let payload: KlipyCategoryResponseDTO = try await fetchJSON(from: components)
        return payload.tags.map(KlipyMetaMapper.toCategory)
    }

    func autocomplete(query: String) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/autocomplete")
        components?.queryItems = metaQueryItems + [
            URLQueryItem(name: "q", value: trimmed),
        ]
        let payload: KlipyStringListResponseDTO = try await fetchJSON(from: components)
        return payload.results
    }

    func searchSuggestions(query: String) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/search_suggestions")
        components?.queryItems = metaQueryItems + [
            URLQueryItem(name: "q", value: trimmed),
        ]
        let payload: KlipyStringListResponseDTO = try await fetchJSON(from: components)
        return payload.results
    }

    func trendingTerms() async throws -> [String] {
        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/trending_terms")
        components?.queryItems = metaQueryItems
        let payload: KlipyStringListResponseDTO = try await fetchJSON(from: components)
        return payload.results
    }

    func registerShare(gifId: String, searchQuery: String?) async throws {
        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/registershare")
        var items = metaQueryItems + [
            URLQueryItem(name: "id", value: gifId),
        ]
        if let searchQuery {
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                items.append(URLQueryItem(name: "q", value: trimmed))
            }
        }
        components?.queryItems = items

        guard let url = components?.url else { return }
        _ = try? await session.data(from: url)
    }

    private var baseQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "key", value: AppConstants.Klipy.apiKey),
            URLQueryItem(name: "limit", value: "\(AppConstants.Klipy.defaultPageLimit)"),
            URLQueryItem(name: "locale", value: AppConstants.Klipy.locale),
            URLQueryItem(name: "country", value: AppConstants.Klipy.country),
            URLQueryItem(name: "contentfilter", value: "low"),
            URLQueryItem(name: "media_filter", value: "tinygif,gif"),
        ]
    }

    private var metaQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "key", value: AppConstants.Klipy.apiKey),
            URLQueryItem(name: "locale", value: AppConstants.Klipy.locale),
            URLQueryItem(name: "country", value: AppConstants.Klipy.country),
        ]
    }

    private func stickerQueryItems(position: String?) -> [URLQueryItem] {
        var items = baseQueryItems
        if let position, !position.isEmpty {
            items.append(URLQueryItem(name: "pos", value: position))
        }
        return items
    }

    private func fetchStickerPage(from components: URLComponents?) async throws -> StickerFetchResult {
        let payload: KlipySearchResponseDTO = try await fetchJSON(from: components)
        let stickers = payload.results.compactMap(StickerMapper.toSticker)
        return StickerFetchResult(stickers: stickers, nextPosition: payload.next)
    }

    private func fetchJSON<T: Decodable>(from components: URLComponents?) async throws -> T {
        guard !AppConstants.Klipy.apiKey.isEmpty else {
            throw StickerError.apiKeyMissing
        }
        guard let url = components?.url else {
            throw StickerError.network("URL KLIPY không hợp lệ.")
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StickerError.network("Phản hồi KLIPY không hợp lệ.")
        }

        if httpResponse.statusCode == 429 {
            throw StickerError.rateLimitExceeded
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw StickerError.network("KLIPY trả về mã \(httpResponse.statusCode).")
        }

        return try decoder.decode(T.self, from: data)
    }
}
