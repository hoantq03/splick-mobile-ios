import Foundation
import SplickDomain

enum StickerMapper {
    static func toSticker(_ dto: KlipyGifDTO) -> Sticker? {
        let asset = dto.mediaFormats.gif ?? dto.mediaFormats.mediumGif ?? dto.mediaFormats.tinyGif
        guard let asset, let url = URL(string: asset.url) else { return nil }

        let previewURL = dto.mediaFormats.tinyGif.flatMap { URL(string: $0.url) }
        return Sticker(
            id: dto.id,
            url: url,
            previewURL: previewURL,
            source: .klipy,
            width: asset.dims?.first,
            height: (asset.dims?.count ?? 0) > 1 ? asset.dims?[1] : nil
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
