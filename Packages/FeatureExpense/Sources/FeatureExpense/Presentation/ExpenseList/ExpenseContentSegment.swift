import Foundation

/// Expense tab pages — order matches feed-style strip: left | center | right.
public enum ExpenseContentSegment: String, CaseIterable, Identifiable, Hashable, Sendable {
    case history
    case overview
    case friends

    public var id: String { rawValue }
}

/// Left → right strip order (History | Overview | Friends).
let expenseSegmentStripOrder: [ExpenseContentSegment] = [.history, .overview, .friends]
