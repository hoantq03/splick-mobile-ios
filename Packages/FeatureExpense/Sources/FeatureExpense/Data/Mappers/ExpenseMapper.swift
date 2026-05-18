import Foundation
import SplickDomain

enum ExpenseMapper {
    static func toExpense(_ dto: ExpenseResponseDTO) -> Expense {
        Expense(
            id: dto.id,
            description: dto.description,
            totalAmount: Decimal(string: dto.totalAmount) ?? 0,
            currency: dto.currency,
            paidBy: toUserSummary(dto.paidBy),
            splits: dto.splits.map(toExpenseSplit),
            groupId: dto.groupId,
            category: ExpenseCategory(rawValue: dto.category) ?? .general,
            status: ExpenseStatus(rawValue: dto.status) ?? .pending,
            createdAt: dto.createdAt,
            settledAt: dto.settledAt
        )
    }

    static func toExpenseSplit(_ dto: ExpenseSplitDTO) -> ExpenseSplit {
        ExpenseSplit(
            id: dto.id,
            user: toUserSummary(dto.user),
            amount: Decimal(string: dto.amount) ?? 0,
            isPaid: dto.isPaid,
            paidAt: dto.paidAt
        )
    }

    static func toUserSummary(_ dto: ExpenseUserDTO) -> UserSummary {
        UserSummary(
            id: dto.id,
            username: dto.username,
            displayName: dto.displayName,
            avatarURL: dto.avatarUrl.flatMap(URL.init(string:))
        )
    }

    static func toDebtSummary(_ dto: DebtSummaryDTO) -> DebtSummary {
        DebtSummary(
            user: toUserSummary(dto.user),
            amount: Decimal(string: dto.amount) ?? 0,
            currency: dto.currency
        )
    }

    static func toRequestDTO(_ request: CreateExpenseRequest) -> CreateExpenseRequestDTO {
        var customAmountsDTO: [String: String]?
        if let customAmounts = request.customAmounts {
            customAmountsDTO = Dictionary(
                uniqueKeysWithValues: customAmounts.map { ($0.key.uuidString, "\($0.value)") }
            )
        }

        return CreateExpenseRequestDTO(
            description: request.description,
            totalAmount: "\(request.totalAmount)",
            currency: request.currency,
            groupId: request.groupId,
            category: request.category.rawValue,
            splitType: request.splitType.rawValue,
            participants: request.participants,
            customAmounts: customAmountsDTO
        )
    }
}
