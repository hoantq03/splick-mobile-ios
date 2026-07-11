import Foundation
import Common
import SplickDomain

protocol KlipyDataSourceProtocol: Sendable {
    func search(query: String) async throws -> [Sticker]
    func trending() async throws -> [Sticker]
}

final class KlipyDataSource: KlipyDataSourceProtocol, @unchecked Sendable {
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

        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/search")
        components?.queryItems = baseQueryItems + [
            URLQueryItem(name: "q", value: trimmed),
        ]
        return try await fetchStickers(from: components)
    }

    func trending() async throws -> [Sticker] {
        var components = URLComponents(string: "\(AppConstants.Klipy.baseURL)/featured")
        components?.queryItems = baseQueryItems
        return try await fetchStickers(from: components)
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

    private func fetchStickers(from components: URLComponents?) async throws -> [Sticker] {
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

        let payload = try decoder.decode(KlipySearchResponseDTO.self, from: data)
        return payload.results.compactMap(StickerMapper.toSticker)
    }
}
