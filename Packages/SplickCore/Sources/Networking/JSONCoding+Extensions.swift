import Foundation

extension JSONDecoder {
    public static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: dateString) {
                return date
            }

            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            if let date = formatter.date(from: dateString) {
                return date
            }

            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    public static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        // Backend/OpenAPI use camelCase (otpCode, deviceInfo). Do not snake_case requests.
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
