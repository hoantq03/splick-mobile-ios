import Foundation

enum AlbumPhotoCursor {
    private static let separator = "|"

    static func encode(createdAt: Date, mediaItemId: UUID) -> String {
        let instant = formatInstant(createdAt)
        let raw = "\(instant)\(separator)\(mediaItemId.uuidString)"
        return base64UrlEncode(raw)
    }

    static func decode(_ cursor: String) -> (createdAt: Date, mediaItemId: UUID)? {
        guard let raw = base64UrlDecode(cursor) else { return nil }
        let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let createdAt = parseInstant(parts[0]),
              let mediaItemId = UUID(uuidString: parts[1]) else {
            return nil
        }
        return (createdAt, mediaItemId)
    }

    /// Formats a date as an ISO-8601 instant string compatible with Java `Instant.toString()`.
    private static func formatInstant(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func parseInstant(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func base64UrlEncode(_ raw: String) -> String {
        Data(raw.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64UrlDecode(_ cursor: String) -> String? {
        var base64 =
            cursor
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: padding))
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
