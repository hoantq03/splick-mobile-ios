import Foundation
import SplickDomain

public enum ExpenseDebtFilter: String, CaseIterable, Identifiable {
    case all
    case oweUnpaid
    case owePaid
    case owedUnpaid
    case owedPaid

    public var id: String { rawValue }

    public var matchingDebtState: ExpenseUserDebtState? {
        switch self {
        case .all: return nil
        case .oweUnpaid: return .oweUnpaid
        case .owePaid: return .owePaid
        case .owedUnpaid: return .owedUnpaid
        case .owedPaid: return .owedPaid
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

    /// Start of the current calendar month (local timezone).
    public static var defaultMonthStart: Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let components = calendar.dateComponents([.year, .month], from: today)
        return calendar.date(from: components)
    }

    public init(
        captionQuery: String = "",
        debtStatus: ExpenseDebtFilter = .all,
        selectedUser: UserSummary? = nil,
        dateFrom: Date? = ExpenseListFilters.defaultMonthStart,
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
        hasCaptionSearch || selectedUser != nil || !isDefaultDateFilter
    }

    /// Default list scope: current calendar month through now (no end bound).
    public var isDefaultDateFilter: Bool {
        guard dateTo == nil, let from = dateFrom, let monthStart = Self.defaultMonthStart else {
            return false
        }
        return Calendar.current.isDate(from, inSameDayAs: monthStart)
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

        if let monthStart = Self.defaultMonthStart,
           Calendar.current.isDate(from, inSameDayAs: monthStart) {
            return .month
        }

        return .week
    }
}
