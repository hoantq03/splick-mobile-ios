import Foundation

struct KlipySearchResponseDTO: Decodable {
    let results: [KlipyGifDTO]
}

struct KlipyGifDTO: Decodable {
    let id: String
    let mediaFormats: KlipyMediaFormatsDTO

    enum CodingKeys: String, CodingKey {
        case id
        case mediaFormats = "media_formats"
    }
}

struct KlipyMediaFormatsDTO: Decodable {
    let tinyGif: KlipyMediaObjectDTO?
    let gif: KlipyMediaObjectDTO?
    let mediumGif: KlipyMediaObjectDTO?

    enum CodingKeys: String, CodingKey {
        case tinyGif = "tinygif"
        case gif
        case mediumGif = "mediumgif"
    }
}

struct KlipyMediaObjectDTO: Decodable {
    let url: String
    let dims: [Int]?
}
