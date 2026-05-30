import Foundation
import SplickDomain

public enum ExpenseDebtFilter: String, CaseIterable, Identifiable {
    case all
    case owe
    case owed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All"
        case .owe: return "I owe"
        case .owed: return "Owed to me"
        }
    }
}

public struct ExpenseListFilters: Equatable {
    public var captionQuery: String = ""
    public var debtStatus: ExpenseDebtFilter = .all
    public var selectedUser: UserSummary?
    public var dateFrom: Date?
    public var dateTo: Date?
    public var isAdvancedExpanded: Bool = false

    public var hasCaptionSearch: Bool {
        !captionQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasAdvancedFilters: Bool {
        debtStatus != .all || selectedUser != nil || dateFrom != nil || dateTo != nil
    }

    public var hasAnyFilter: Bool {
        hasCaptionSearch || hasAdvancedFilters
    }
}
