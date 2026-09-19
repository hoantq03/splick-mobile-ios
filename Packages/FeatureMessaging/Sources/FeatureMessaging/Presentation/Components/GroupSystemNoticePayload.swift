import Foundation
import SplickDomain

/// Mirrors backend `GroupSystemNoticePayload` so inbox/thread can recover leave notices
/// when `message_type` is missing from older projections.
enum GroupSystemNoticePayload {
    static let memberLeftPrefix = "\u{2063}LEFT\u{2063}"

    static func displaysAsSystemNotice(_ message: ChatMessage) -> Bool {
        message.isSystemNotice || isMemberLeft(message.body)
    }

    static func isMemberLeft(_ body: String?) -> Bool {
        (body ?? "").hasPrefix(memberLeftPrefix)
    }

    static func memberLeftDisplayName(_ body: String?) -> String {
        let raw = body ?? ""
        if raw.hasPrefix(memberLeftPrefix) {
            return String(raw.dropFirst(memberLeftPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
