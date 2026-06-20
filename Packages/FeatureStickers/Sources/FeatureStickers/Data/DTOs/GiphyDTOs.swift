import Foundation
import Common
import SplickDomain

struct GiphySearchResponseDTO: Decodable {
    let data: [GiphyGifDTO]
    let meta: GiphyMetaDTO?
}

struct GiphyGifDTO: Decodable {
    let id: String
    let images: GiphyImagesDTO
}

struct GiphyImagesDTO: Decodable {
    let fixedWidth: GiphyImageAssetDTO?
    let downsized: GiphyImageAssetDTO?
    let original: GiphyImageAssetDTO?

    enum CodingKeys: String, CodingKey {
        case fixedWidth = "fixed_width"
        case downsized
        case original
    }
}

struct GiphyImageAssetDTO: Decodable {
    let url: String
    let width: String?
    let height: String?
}

struct GiphyMetaDTO: Decodable {
    let status: Int?
    let msg: String?
}
