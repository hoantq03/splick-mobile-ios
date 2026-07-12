import Foundation
import Networking
import SplickDomain

struct StickerFavoriteDTO: Decodable, Sendable {
    let id: UUID
    let provider: String
    let externalId: String
    let url: String
    let previewUrl: String?
    let name: String?
    let width: Int?
    let height: Int?
}

struct UpsertStickerFavoriteRequestDTO: Encodable, Sendable {
    let provider: String
    let externalId: String
    let url: String
    let previewUrl: String?
    let name: String?
    let width: Int?
    let height: Int?
}

enum FavoriteStickerEndpoint: APIEndpoint {
    case list
    case upsert(UpsertStickerFavoriteRequestDTO)
    case delete(id: UUID)

    var path: String {
        switch self {
        case .list, .upsert:
            return "/v1/feed/sticker-favorites"
        case .delete(let id):
            return "/v1/feed/sticker-favorites/\(id.uuidString)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list:
            return .get
        case .upsert:
            return .put
        case .delete:
            return .delete
        }
    }

    var body: Encodable? {
        switch self {
        case .upsert(let request):
            return request
        case .list, .delete:
            return nil
        }
    }
}

enum FavoriteStickerMapper {
    static func toSticker(_ dto: StickerFavoriteDTO, fallbackGroupId: UUID? = nil) -> Sticker? {
        guard let url = URL(string: dto.url) else { return nil }
        let source: StickerSource
        switch dto.provider.lowercased() {
        case "klipy":
            source = .klipy
        case "custom":
            if let fallbackGroupId {
                source = .custom(groupId: fallbackGroupId)
            } else {
                source = .klipy
            }
        default:
            source = .klipy
        }

        return Sticker(
            id: dto.externalId,
            url: url,
            previewURL: dto.previewUrl.flatMap(URL.init(string:)),
            source: source,
            width: dto.width,
            height: dto.height,
            favoriteId: dto.id
        )
    }
}

final class FavoriteStickerDataSource: @unchecked Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchFavorites() async throws -> [StickerFavoriteDTO] {
        try await apiClient.request(FavoriteStickerEndpoint.list)
    }

    func upsert(_ request: UpsertStickerFavoriteRequestDTO) async throws -> StickerFavoriteDTO {
        try await apiClient.request(FavoriteStickerEndpoint.upsert(request))
    }

    func delete(id: UUID) async throws {
        try await apiClient.request(FavoriteStickerEndpoint.delete(id: id))
    }
}

public final class FavoriteStickerRepositoryImpl: FavoriteStickerRepositoryProtocol, @unchecked Sendable {
    private let dataSource: FavoriteStickerDataSource
    private let fallbackGroupId: UUID?

    public init(apiClient: APIClientProtocol, fallbackGroupId: UUID? = nil) {
        self.dataSource = FavoriteStickerDataSource(apiClient: apiClient)
        self.fallbackGroupId = fallbackGroupId
    }

    public func fetchFavorites() async throws -> [Sticker] {
        let dtos = try await dataSource.fetchFavorites()
        return dtos.compactMap { FavoriteStickerMapper.toSticker($0, fallbackGroupId: fallbackGroupId) }
    }

    public func addFavorite(
        provider: String,
        externalId: String,
        url: URL,
        previewURL: URL?,
        name: String?,
        width: Int?,
        height: Int?
    ) async throws -> Sticker {
        let dto = try await dataSource.upsert(
            UpsertStickerFavoriteRequestDTO(
                provider: provider,
                externalId: externalId,
                url: url.absoluteString,
                previewUrl: previewURL?.absoluteString,
                name: name,
                width: width,
                height: height
            )
        )
        guard let sticker = FavoriteStickerMapper.toSticker(dto, fallbackGroupId: fallbackGroupId) else {
            throw URLError(.badURL)
        }
        return sticker
    }

    public func removeFavorite(id: UUID) async throws {
        try await dataSource.delete(id: id)
    }
}
