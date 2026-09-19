import Foundation

/// Splits outbound message bodies to match backend `@Size(max = 2000)` on
/// `SendMessageRequest.body` / DB column length.
///
/// Length is measured in UTF-16 code units (same as Java `String.length()`).
enum MessageBodyChunker {
    static let maxLength = 2000

    /// Prefer a whitespace break in the last 20% of a full window.
    private static let softBreakRatio = 0.8

    /// Empty input yields `[]` — callers decide whether to send media-only `""`.
    static func chunk(_ body: String, maxLength: Int = Self.maxLength) -> [String] {
        precondition(maxLength > 0)
        guard !body.isEmpty else { return [] }
        let utf16Count = body.utf16.count
        guard utf16Count > maxLength else { return [body] }

        var chunks: [String] = []
        var startUTF16 = 0
        while startUTF16 < utf16Count {
            let remaining = utf16Count - startUTF16
            if remaining <= maxLength {
                if let slice = substring(body, utf16Start: startUTF16, utf16End: utf16Count) {
                    chunks.append(slice)
                }
                break
            }
            var endUTF16 = startUTF16 + maxLength
            let softFloor = startUTF16 + Int(Double(maxLength) * softBreakRatio)
            if let soft = findSoftBreakUTF16(in: body, softFloor: softFloor, exclusiveEnd: endUTF16) {
                endUTF16 = soft
            }
            if let slice = substring(body, utf16Start: startUTF16, utf16End: endUTF16) {
                chunks.append(slice)
            }
            startUTF16 = endUTF16
        }
        return chunks
    }

    /// Bodies ready to send: empty → `[""]` so media-only sends still get one part.
    static func partsForSend(_ body: String, maxLength: Int = Self.maxLength) -> [String] {
        let parts = chunk(body, maxLength: maxLength)
        return parts.isEmpty ? [""] : parts
    }

    static func clampForEdit(_ body: String, maxLength: Int = Self.maxLength) -> String {
        guard body.utf16.count > maxLength else { return body }
        return substring(body, utf16Start: 0, utf16End: maxLength) ?? String(body.prefix(maxLength))
    }

    private static func findSoftBreakUTF16(in body: String, softFloor: Int, exclusiveEnd: Int) -> Int? {
        let utf16 = body.utf16
        var i = exclusiveEnd - 1
        while i >= softFloor {
            let idx = utf16.index(utf16.startIndex, offsetBy: i)
            let unit = utf16[idx]
            // Match common whitespace code units (aligned with Java Character.isWhitespace for BMP).
            if unit == 0x20 || unit == 0x0A || unit == 0x0D || unit == 0x09 || unit == 0x0C {
                return i + 1
            }
            i -= 1
        }
        return nil
    }

    private static func substring(_ body: String, utf16Start: Int, utf16End: Int) -> String? {
        guard utf16Start < utf16End else { return nil }
        let utf16 = body.utf16
        guard
            let start = utf16.index(utf16.startIndex, offsetBy: utf16Start, limitedBy: utf16.endIndex),
            let end = utf16.index(utf16.startIndex, offsetBy: utf16End, limitedBy: utf16.endIndex),
            let from = String.Index(start, within: body),
            let to = String.Index(end, within: body)
        else {
            return nil
        }
        return String(body[from..<to])
    }
}
