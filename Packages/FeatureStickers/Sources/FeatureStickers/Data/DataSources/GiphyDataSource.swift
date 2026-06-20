import Foundation
import Common
import SplickDomain

protocol GiphyDataSourceProtocol: Sendable {
    func search(query: String) async throws -> [Sticker]
    func trending() async throws -> [Sticker]
}

final class GiphyDataSource: GiphyDataSourceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .splick) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func search(query: String) async throws -> [Sticker] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await trending()
        }

        var components = URLComponents(string: "\(AppConstants.Giphy.baseURL)/search")
        components?.queryItems = baseQueryItems + [
            URLQueryItem(name: "q", value: trimmed),
        ]
        return try await fetchStickers(from: components)
    }

    func trending() async throws -> [Sticker] {
        var components = URLComponents(string: "\(AppConstants.Giphy.baseURL)/trending")
        components?.queryItems = baseQueryItems
        return try await fetchStickers(from: components)
    }

    private var baseQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "api_key", value: AppConstants.Giphy.apiKey),
            URLQueryItem(name: "limit", value: "\(AppConstants.Giphy.defaultPageLimit)"),
            URLQueryItem(name: "rating", value: "pg"),
        ]
    }

    private func fetchStickers(from components: URLComponents?) async throws -> [Sticker] {
        guard !AppConstants.Giphy.apiKey.isEmpty else {
            throw StickerError.apiKeyMissing
        }
        guard let url = components?.url else {
            throw StickerError.network("URL Giphy không hợp lệ.")
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StickerError.network("Phản hồi Giphy không hợp lệ.")
        }

        if httpResponse.statusCode == 429 {
            throw StickerError.rateLimitExceeded
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw StickerError.network("Giphy trả về mã \(httpResponse.statusCode).")
        }

        let payload = try decoder.decode(GiphySearchResponseDTO.self, from: data)
        if payload.meta?.status == 429 {
            throw StickerError.rateLimitExceeded
        }

        return payload.data.compactMap(StickerMapper.toSticker)
    }
}
