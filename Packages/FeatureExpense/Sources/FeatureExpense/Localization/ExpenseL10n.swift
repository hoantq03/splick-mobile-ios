import Localization

extension ExpenseDebtFilter {
    @MainActor
    public func title(using languageService: LanguageService) -> String {
        switch self {
        case .all: return languageService.text(.expenseDebtAll)
        case .owe: return languageService.text(.expenseDebtOwe)
        case .owed: return languageService.text(.expenseDebtOwed)
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
