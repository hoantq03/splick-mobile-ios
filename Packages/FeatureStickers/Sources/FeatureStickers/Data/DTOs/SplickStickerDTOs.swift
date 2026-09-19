import Foundation

struct SplickStickerDTO: Decodable {
    let id: String
    let url: String
    let previewUrl: String?
    let width: Int?
    let height: Int?
}
