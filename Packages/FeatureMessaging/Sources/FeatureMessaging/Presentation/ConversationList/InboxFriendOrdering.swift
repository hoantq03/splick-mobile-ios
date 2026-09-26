import Foundation
import Common
import SplickDomain

enum InboxFriendOrdering {
    /// Online friends first, then the most recently seen. Name breaks remaining ties.
    static func sorted(
        _ friends: [UserSummary],
        presence: [UUID: UserPresenceState]
    ) -> [UserSummary] {
        friends.sorted { lhs, rhs in
            let left = presence[lhs.id]
            let right = presence[rhs.id]
            let leftOnline = left?.isOnline == true
            let rightOnline = right?.isOnline == true
            if leftOnline != rightOnline {
                return leftOnline
            }
            let leftSeen = left?.lastSeenAt ?? .distantPast
            let rightSeen = right?.lastSeenAt ?? .distantPast
            if leftSeen != rightSeen {
                return leftSeen > rightSeen
            }
            let nameOrder = lhs.preferredName.localizedStandardCompare(rhs.preferredName)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
