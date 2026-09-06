import Foundation

struct KlipySearchResponseDTO: Decodable {
    let results: [KlipyGifDTO]
    let next: String?

    enum CodingKeys: String, CodingKey {
        case results, next, data
    }

    enum NestedKeys: String, CodingKey {
        case data, results, next
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let results = try container.decodeIfPresent([KlipyGifDTO].self, forKey: .results) {
            self.results = results
            self.next = try container.decodeIfPresent(String.self, forKey: .next)
            return
        }

        if var nested = try? container.nestedContainer(keyedBy: NestedKeys.self, forKey: .data) {
            let nestedResults = (try? nested.decode([KlipyGifDTO].self, forKey: .results))
                ?? (try? nested.decode([KlipyGifDTO].self, forKey: .data))
                ?? []
            self.results = nestedResults
            self.next = (try? nested.decodeIfPresent(String.self, forKey: .next))
                ?? (try? container.decodeIfPresent(String.self, forKey: .next))
            return
        }

        if let nestedResults = try? container.decode([KlipyGifDTO].self, forKey: .data) {
            self.results = nestedResults
            self.next = try container.decodeIfPresent(String.self, forKey: .next)
            return
        }

        self.results = []
        self.next = try container.decodeIfPresent(String.self, forKey: .next)
    }
}

struct KlipyGifDTO: Decodable {
    let id: String
    let mediaFormats: KlipyMediaFormatsDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaFormats = "media_formats"
        case files
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let numericId = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericId)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "KLIPY gif id must be a string or integer."
            )
        }
        if let formats = try container.decodeIfPresent(KlipyMediaFormatsDTO.self, forKey: .mediaFormats) {
            mediaFormats = formats
        } else {
            mediaFormats = try container.decodeIfPresent(KlipyMediaFormatsDTO.self, forKey: .files)
        }
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

struct KlipyCategoryResponseDTO: Decodable {
    let tags: [KlipyCategoryDTO]
}

struct KlipyCategoryDTO: Decodable {
    let searchterm: String
    let name: String
    let image: String?
}

struct KlipyStringListResponseDTO: Decodable {
    let results: [String]
}
