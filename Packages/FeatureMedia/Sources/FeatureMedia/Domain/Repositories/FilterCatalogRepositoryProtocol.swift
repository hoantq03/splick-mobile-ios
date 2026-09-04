import Foundation

public enum FilterCatalogType: String, Codable, Sendable, Equatable {
    case lut = "LUT"
    case matrix = "MATRIX"
    case ar = "AR"
}

public struct FilterCatalogItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let slug: String
    public let name: String
    public let type: FilterCatalogType
    public let thumbnailURL: URL?
    public let assetURL: URL
    public let version: Int
    public let minAppVersion: String?

    public init(
        id: UUID,
        slug: String,
        name: String,
        type: FilterCatalogType,
        thumbnailURL: URL?,
        assetURL: URL,
        version: Int,
        minAppVersion: String?
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.type = type
        self.thumbnailURL = thumbnailURL
        self.assetURL = assetURL
        self.version = version
        self.minAppVersion = minAppVersion
    }
}

public protocol FilterCatalogRepositoryProtocol: Sendable {
    func listFilters() async throws -> [FilterCatalogItem]
}
