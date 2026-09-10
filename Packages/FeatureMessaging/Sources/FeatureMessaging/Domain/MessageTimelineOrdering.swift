import Foundation
import SplickDomain

enum MessageTimelineOrdering {
    /// Oldest → newest. Used for every in-memory thread list mutation.
    static func sortedChronologically(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted { lhs, rhs in
            if lhs.sequenceNo > 0, rhs.sequenceNo > 0, lhs.sequenceNo != rhs.sequenceNo {
                return lhs.sequenceNo < rhs.sequenceNo
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
