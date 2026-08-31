import XCTest
import Common
import SplickDomain

@testable import FeatureExpense

final class CreateExpenseUseCaseTests: XCTestCase {
    func test_execute_rejectsAmountBelowMinimum() async {
        let useCase = CreateExpenseUseCase(repository: StubExpenseRepository())
        let request = CreateExpenseRequest(
            description: "Lunch",
            totalAmount: 999,
            participants: [UUID()]
        )

        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected validation error")
        } catch let error as AppError {
            guard case .validation(let message) = error else {
                return XCTFail("Expected validation error, got \(error)")
            }
            XCTAssertTrue(message.contains("1000"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_acceptsAmountAtMinimum() async throws {
        let repository = StubExpenseRepository()
        let useCase = CreateExpenseUseCase(repository: repository)
        let request = CreateExpenseRequest(
            description: "Lunch",
            totalAmount: 1_000,
            participants: [UUID()]
        )

        let expense = try await useCase.execute(request)
        XCTAssertEqual(expense.totalAmount, 1_000)
        let callCount = await repository.createCallCount
        XCTAssertEqual(callCount, 1)
    }
}

private actor StubExpenseRepository: ExpenseRepositoryProtocol {
    private(set) var createCallCount = 0

    func fetchExpenses(groupId: UUID?, page: Int, limit: Int, cursor: String?) async throws -> [Expense] {
        []
    }

    func fetchExpense(id: UUID) async throws -> Expense {
        throw AppError.unknown("unused")
    }

    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense {
        createCallCount += 1
        return Expense(
            id: UUID(),
            description: request.description,
            totalAmount: request.totalAmount,
            paidBy: UserSummary(id: UUID(), username: "me", displayName: "Me", avatarURL: nil),
            splits: [],
            groupId: request.groupId,
            category: request.category
        )
    }

    func settleExpense(expenseId: UUID, splitId: UUID) async throws {}

    func fetchDebtSummary(groupId: UUID?) async throws -> [DebtSummary] {
        []
    }

    func fetchMonthlySummary(months: Int) async throws -> MonthlyExpenseSummary {
        let month = MonthData(year: 2026, month: 1, totalSettledReceived: 0, totalSettledPaid: 0)
        return MonthlyExpenseSummary(currency: "VND", currentMonth: month, months: [month])
    }

    func fetchExpenses(
        counterpartyId: UUID,
        page: Int,
        limit: Int,
        status: CounterpartyExpenseStatus,
        cursor: String?
    ) async throws -> ExpensePage {
        ExpensePage(expenses: [], page: 0, totalPages: 1, totalItems: 0, hasNext: false)
    }

    func fetchNetting(counterpartyId: UUID) async throws -> NettingSummary {
        throw AppError.unknown("unused")
    }

    func submitBulkSettlement(
        counterpartyId: UUID,
        evidenceURL: URL,
        note: String?
    ) async throws -> BulkSettlement {
        throw AppError.unknown("unused")
    }

    func approveBulkSettlement(id: UUID) async throws -> BulkSettlement {
        throw AppError.unknown("unused")
    }

    func rejectBulkSettlement(id: UUID, reason: String?) async throws -> BulkSettlement {
        throw AppError.unknown("unused")
    }
}
