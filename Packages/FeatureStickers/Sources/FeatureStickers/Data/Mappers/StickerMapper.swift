import Foundation
import SplickDomain

enum StickerMapper {
    static func toSticker(_ dto: GiphyGifDTO) -> Sticker? {
        let asset = dto.images.fixedWidth ?? dto.images.downsized ?? dto.images.original
        guard let asset, let url = URL(string: asset.url) else { return nil }

        let previewURL = dto.images.fixedWidth.flatMap { URL(string: $0.url) }
        return Sticker(
            id: dto.id,
            url: url,
            previewURL: previewURL,
            source: .giphy,
            width: asset.width.flatMap(Int.init),
            height: asset.height.flatMap(Int.init)
        )
    }

    static func toSticker(_ dto: SplickStickerDTO, groupId: UUID) -> Sticker? {
        guard let url = URL(string: dto.url) else { return nil }
        return Sticker(
            id: dto.id,
            url: url,
            previewURL: dto.previewUrl.flatMap(URL.init(string:)),
            source: .custom(groupId: groupId),
            width: dto.width,
            height: dto.height
        )
    }
}
