import Foundation

struct ExpenseResponseDTO: Decodable {
    let id: UUID
    let description: String
    let totalAmount: String
    let currency: String
    let paidBy: ExpenseUserDTO
    let splits: [ExpenseSplitDTO]
    let groupId: UUID?
    let category: String
    let status: String
    let createdAt: Date
}

struct ExpenseUserDTO: Decodable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
}

struct ExpenseSplitDTO: Decodable {
    let id: UUID
    let user: ExpenseUserDTO
    let amount: String
    let isPaid: Bool
}

struct CreateExpenseRequestDTO: Encodable {
    let description: String
    let totalAmount: String
    let currency: String
    let groupId: UUID?
    let category: String
    let splitType: String
    let participants: [UUID]
    let customAmounts: [String: String]?
}

struct DebtSummaryDTO: Decodable {
    let user: ExpenseUserDTO
    let amount: String
    let currency: String
}

struct SettleExpenseRequestDTO: Encodable {
    let splitId: UUID
}
