import Foundation

/// Builds the chat body for an in-app post share. The post URL is always kept;
/// a user note is truncated first when the combined body would exceed the send limit.
public enum SharePostMessageComposer {
    public static let maxLength = 2000

    public static func composeBody(note: String, shareURL: URL) -> String {
        let url = shareURL.absoluteString
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return clamp(url, maxLength: maxLength)
        }
        let separator = "\n"
        let budgetForNote = maxLength - url.utf16.count - separator.utf16.count
        guard budgetForNote > 0 else {
            return clamp(url, maxLength: maxLength)
        }
        return clamp(trimmed, maxLength: budgetForNote) + separator + url
    }

    private static func clamp(_ text: String, maxLength: Int) -> String {
        guard text.utf16.count > maxLength else { return text }
        let utf16 = text.utf16
        guard
            let end = utf16.index(utf16.startIndex, offsetBy: maxLength, limitedBy: utf16.endIndex),
            let to = String.Index(end, within: text)
        else {
            return String(text.prefix(maxLength))
        }
        return String(text[text.startIndex..<to])
    }
}
