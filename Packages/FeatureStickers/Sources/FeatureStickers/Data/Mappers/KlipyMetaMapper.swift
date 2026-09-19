import Foundation
import SplickDomain

enum KlipyMetaMapper {
    static func toCategory(_ dto: KlipyCategoryDTO) -> StickerCategory {
        StickerCategory(
            id: dto.searchterm,
            name: dto.name,
            previewURL: dto.image.flatMap(URL.init(string:))
        )
    }
}
