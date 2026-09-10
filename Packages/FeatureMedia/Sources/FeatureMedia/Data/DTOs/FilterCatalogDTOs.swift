import Foundation

struct FilterCatalogItemDTO: Decodable {
    let id: UUID
    let slug: String
    let name: String
    let type: String
    let thumbnailUrl: String?
    let assetUrl: String
    let version: Int
    let minAppVersion: String?
}

struct FilterCatalogListResponseDTO: Decodable {
    let items: [FilterCatalogItemDTO]
}

enum FilterCatalogMapper {
    static func map(_ dto: FilterCatalogItemDTO) throws -> FilterCatalogItem {
        guard let assetURL = URL(string: dto.assetUrl) else {
            throw FilterCatalogError.invalidAssetURL
        }
        let type = FilterCatalogType(rawValue: dto.type) ?? .lut
        return FilterCatalogItem(
            id: dto.id,
            slug: dto.slug,
            name: dto.name,
            type: type,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:)),
            assetURL: assetURL,
            version: dto.version,
            minAppVersion: dto.minAppVersion
        )
    }
}

enum FilterCatalogError: Error {
    case invalidAssetURL
}
