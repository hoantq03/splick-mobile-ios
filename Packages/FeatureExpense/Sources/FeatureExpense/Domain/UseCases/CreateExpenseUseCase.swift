import Foundation
import Common
import SplickDomain

public protocol CreateExpenseUseCaseProtocol: Sendable {
    func execute(_ request: CreateExpenseRequest) async throws -> Expense
}

public final class CreateExpenseUseCase: CreateExpenseUseCaseProtocol, Sendable {
    private let repository: ExpenseRepositoryProtocol

    public init(repository: ExpenseRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ request: CreateExpenseRequest) async throws -> Expense {
        guard !request.description.isBlank else {
            throw AppError.validation("Description is required")
        }

        guard request.totalAmount > 0 else {
            throw AppError.validation("Amount must be greater than zero")
        }

        guard !request.participants.isEmpty else {
            throw AppError.validation("At least one participant is required")
        }

        if request.splitType == .exact, let customAmounts = request.customAmounts {
            let sum = customAmounts.values.reduce(Decimal.zero, +)
            guard sum == request.totalAmount else {
                throw AppError.validation("Custom amounts must add up to the total")
            }
        }

        return try await repository.createExpense(request)
    }
}
