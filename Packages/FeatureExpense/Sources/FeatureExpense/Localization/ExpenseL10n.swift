import Localization
import SplickDomain

extension ExpenseCategory {
    @MainActor
    public func title(using languageService: LanguageService) -> String {
        switch self {
        case .food: return languageService.text(.expenseCategoryFood)
        case .transport: return languageService.text(.expenseCategoryTransport)
        case .housing: return languageService.text(.expenseCategoryHousing)
        case .entertainment: return languageService.text(.expenseCategoryEntertainment)
        case .shopping: return languageService.text(.expenseCategoryShopping)
        case .utilities: return languageService.text(.expenseCategoryUtilities)
        case .travel: return languageService.text(.expenseCategoryTravel)
        case .general: return languageService.text(.expenseCategoryGeneral)
        }
    }
}

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
        case .pendingApproval:
            return languageService.text(.expenseFilterPendingApproval)
        case .repaid:
            return languageService.text(.expenseFilterRepaidSuccess)
        }
    }

    @MainActor
    public func historyTitle(using languageService: LanguageService) -> String {
        switch self {
        case .all:
            return languageService.text(.expenseDebtAll)
        case .oweUnpaid:
            return languageService.text(.expenseFilterIOweUnpaid)
        case .owedUnpaid:
            return languageService.text(.expenseFilterOwedUnpaid)
        case .pendingApproval:
            return languageService.text(.expenseFilterPendingApproval)
        case .repaid:
            return languageService.text(.expenseFilterRepaidSuccess)
        case .owePaid, .owedPaid:
            return title(using: languageService)
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
