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

public enum ExpenseDatePreset: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case all

    public var id: String { rawValue }
}

public struct ExpenseListFilters: Equatable {
    public var captionQuery: String = ""
    public var debtStatus: ExpenseDebtFilter = .all
    public var selectedUser: UserSummary?
    public var dateFrom: Date?
    public var dateTo: Date?
    public var isAdvancedExpanded: Bool = false

    public static var defaultWeekStart: Date? {
        Calendar.current.date(
            byAdding: .day,
            value: -7,
            to: Calendar.current.startOfDay(for: .now)
        )
    }

    public init(
        captionQuery: String = "",
        debtStatus: ExpenseDebtFilter = .all,
        selectedUser: UserSummary? = nil,
        dateFrom: Date? = ExpenseListFilters.defaultWeekStart,
        dateTo: Date? = nil,
        isAdvancedExpanded: Bool = false
    ) {
        self.captionQuery = captionQuery
        self.debtStatus = debtStatus
        self.selectedUser = selectedUser
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.isAdvancedExpanded = isAdvancedExpanded
    }

    public var hasCaptionSearch: Bool {
        !captionQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasAdvancedFilters: Bool {
        debtStatus != .all || selectedUser != nil || dateFrom != nil || dateTo != nil
    }

    public var hasAnyFilter: Bool {
        hasCaptionSearch || hasAdvancedFilters
    }

    public var hasNonDefaultListFilters: Bool {
        hasCaptionSearch || selectedUser != nil || activeDatePreset != .week
    }

    public var activeDatePreset: ExpenseDatePreset {
        guard let from = dateFrom else {
            return dateTo == nil ? .all : .week
        }

        if dateTo != nil { return .week }

        if let weekStart = Self.defaultWeekStart,
           Calendar.current.isDate(from, inSameDayAs: weekStart) {
            return .week
        }

        if let monthStart = Calendar.current.date(
            byAdding: .day,
            value: -30,
            to: Calendar.current.startOfDay(for: .now)
        ),
        Calendar.current.isDate(from, inSameDayAs: monthStart) {
            return .month
        }

        return .week
    }
}
