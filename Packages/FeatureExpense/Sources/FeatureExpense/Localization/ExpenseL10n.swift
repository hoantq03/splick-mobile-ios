import Localization

extension ExpenseDebtFilter {
    @MainActor
    public func title(using languageService: LanguageService) -> String {
        switch self {
        case .all:
            return languageService.text(.expenseDebtAll)
        case .oweUnpaid:
            return languageService.text(.expenseDebtOweUnpaid)
        case .owePaid:
            return languageService.text(.expenseDebtOwePaid)
        case .owedUnpaid:
            return languageService.text(.expenseDebtOwedUnpaid)
        case .owedPaid:
            return languageService.text(.expenseDebtOwedPaid)
        }
    }
}

extension SplitType {
    @MainActor
    public func title(using languageService: LanguageService) -> String {
        switch self {
        case .equal: return languageService.text(.expenseSplitEqual)
        case .exact: return languageService.text(.expenseSplitExact)
        case .percentage: return languageService.text(.expenseSplitPercentage)
        }
    }
}
