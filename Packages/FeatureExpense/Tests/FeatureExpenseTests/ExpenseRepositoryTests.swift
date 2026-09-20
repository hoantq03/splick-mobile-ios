import XCTest
import SplickDomain
import Common
import Networking
@testable import FeatureExpense

private final class MockAPIClientForExpenseRepo: APIClientProtocol, @unchecked Sendable {
    var lastEndpoint: APIEndpoint?
    var mockResponse: Any?
    var errorToThrow: Error?

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        lastEndpoint = endpoint
        if let error = errorToThrow { throw error }
        guard let response = mockResponse as? T else {
            fatalError("Mock response type mismatch. Expected \(T.self), got \(String(describing: mockResponse))")
        }
        return response
    }

    func request(_ endpoint: APIEndpoint) async throws {
        lastEndpoint = endpoint
        if let error = errorToThrow { throw error }
    }

    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
        lastEndpoint = endpoint
        if let error = errorToThrow { throw error }
        guard let response = mockResponse as? T else {
            fatalError("Mock response mismatch for upload")
        }
        return response
    }
}

final class ExpenseRepositoryTests: XCTestCase {

    private var apiClient: MockAPIClientForExpenseRepo!
    private var sut: ExpenseRepository!

    override func setUp() {
        super.setUp()
        apiClient = MockAPIClientForExpenseRepo()
        sut = ExpenseRepository(apiClient: apiClient)
    }

    override func tearDown() {
        apiClient = nil
        sut = nil
        super.tearDown()
    }

    func testFetchExpenses() async throws {
        let expenseId = UUID()
        let dto = ExpenseResponseDTO(
            id: expenseId,
            description: "Dinner",
            totalAmount: "100000",
            currency: "VND",
            paidBy: ExpenseUserDTO(id: UUID(), username: "payer", displayName: "Payer", avatarUrl: nil),
            splits: [],
            groupId: nil,
            postId: nil,
            category: "FOOD",
            status: "PENDING",
            createdAt: Date(),
            settledAt: nil
        )
        apiClient.mockResponse = [dto]

        let expenses = try await sut.fetchExpenses(groupId: nil, page: 0, limit: 20, cursor: nil)
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses.first?.id, expenseId)
        XCTAssertEqual(expenses.first?.totalAmount, 100000)
    }

    func testFetchExpenseById() async throws {
        let expenseId = UUID()
        let dto = ExpenseResponseDTO(
            id: expenseId,
            description: "Coffee",
            totalAmount: "50000",
            currency: "VND",
            paidBy: ExpenseUserDTO(id: UUID(), username: "payer", displayName: "Payer", avatarUrl: nil),
            splits: [],
            groupId: nil,
            postId: nil,
            category: "FOOD",
            status: "PENDING",
            createdAt: Date(),
            settledAt: nil
        )
        apiClient.mockResponse = dto

        let expense = try await sut.fetchExpense(id: expenseId)
        XCTAssertEqual(expense.id, expenseId)
        XCTAssertEqual(expense.description, "Coffee")
    }

    func testCreateExpense() async throws {
        let expenseId = UUID()
        let dto = ExpenseResponseDTO(
            id: expenseId,
            description: "Lunch",
            totalAmount: "120000",
            currency: "VND",
            paidBy: ExpenseUserDTO(id: UUID(), username: "payer", displayName: "Payer", avatarUrl: nil),
            splits: [],
            groupId: nil,
            postId: nil,
            category: "FOOD",
            status: "PENDING",
            createdAt: Date(),
            settledAt: nil
        )
        apiClient.mockResponse = dto

        let req = CreateExpenseRequest(
            description: "Lunch",
            totalAmount: 120000,
            participants: [UUID()]
        )
        let created = try await sut.createExpense(req)
        XCTAssertEqual(created.id, expenseId)
    }

    func testSettleExpense() async throws {
        let expenseId = UUID()
        let splitId = UUID()
        try await sut.settleExpense(expenseId: expenseId, splitId: splitId)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testFetchDebtSummary() async throws {
        let pageDTO = DebtSummaryPageDTO(content: [
            DebtSummaryDTO(
                user: ExpenseUserDTO(id: UUID(), username: "debtor", displayName: "Debtor", avatarUrl: nil),
                amount: "250000",
                currency: "VND"
            )
        ])
        apiClient.mockResponse = pageDTO

        let debts = try await sut.fetchDebtSummary(groupId: nil)
        XCTAssertEqual(debts.count, 1)
        XCTAssertEqual(debts.first?.amount, 250000)
    }

    func testFetchMonthlySummary() async throws {
        let monthData = MonthDataDTO(year: 2026, month: 9, totalSettledReceived: "500000", totalSettledPaid: "300000")
        let dto = MonthlyExpenseSummaryDTO(
            currency: "VND",
            currentMonth: monthData,
            months: [monthData]
        )
        apiClient.mockResponse = dto

        let summary = try await sut.fetchMonthlySummary(months: 6)
        XCTAssertEqual(summary.currency, "VND")
        XCTAssertEqual(summary.currentMonth.totalSettledReceived, 500000)
        XCTAssertEqual(summary.months.count, 1)
    }

    func testFetchOverview() async throws {
        let overviewDTO = ExpenseOverviewDTO(
            balance: ExpenseBalanceSectionDTO(
                youOwe: "100000",
                owedToYou: "200000",
                netBalance: "100000",
                currency: "VND",
                topBalances: []
            ),
            needsAttention: ExpenseNeedsAttentionSectionDTO(
                pendingPaymentRequestCount: 2,
                expensesNeedingConfirmationCount: 1,
                outstandingSettlementCount: 0,
                totalActionItems: 3,
                items: []
            ),
            recentExpenses: [],
            totalSpending: ExpenseTotalSpendingSectionDTO(
                currentPeriodTotal: "500000",
                previousPeriodTotal: "400000",
                percentageChange: "25",
                currency: "VND"
            )
        )
        apiClient.mockResponse = overviewDTO

        let overview = try await sut.fetchOverview()
        XCTAssertEqual(overview.balance.youOwe, 100000)
        XCTAssertEqual(overview.balance.owedToYou, 200000)
        XCTAssertEqual(overview.needsAttention.totalActionItems, 3)
        XCTAssertEqual(overview.totalSpending.percentageChange, 25)
    }

    func testFetchSpendingAnalytics() async throws {
        let analyticsDTO = SpendingAnalyticsDTO(
            trend: [SpendingTrendPointDTO(bucketStart: Date(), amount: "150000")],
            categories: [SpendingCategoryBreakdownDTO(category: "FOOD", amount: "150000", percentage: "100")],
            currency: "VND"
        )
        apiClient.mockResponse = analyticsDTO

        let analytics = try await sut.fetchSpendingAnalytics(period: .month, months: 3)
        XCTAssertEqual(analytics.trend.count, 1)
        XCTAssertEqual(analytics.categories.count, 1)
        XCTAssertEqual(analytics.currency, "VND")
    }

    func testFetchGroupExpenseSummary() async throws {
        let grpDTO = GroupExpenseSummaryDTO(groups: [
            GroupExpenseItemDTO(
                groupId: UUID(),
                groupName: "Roommates",
                groupAvatarUrl: "https://example.com/avatar.jpg",
                totalGroupSpending: "2000000",
                userPaidTotal: "1000000",
                userBalance: "0",
                currency: "VND",
                memberAvatars: []
            )
        ])
        apiClient.mockResponse = grpDTO

        let groupSummary = try await sut.fetchGroupExpenseSummary()
        XCTAssertEqual(groupSummary.groups.count, 1)
        XCTAssertEqual(groupSummary.groups.first?.groupName, "Roommates")
    }

    func testFetchExpensesWithCounterparty() async throws {
        let pageResponse = ExpensePageResponseDTO<ExpenseResponseDTO>(
            content: [],
            page: 0,
            limit: 20,
            totalElements: 0,
            totalPages: 0,
            nextCursor: nil
        )
        apiClient.mockResponse = pageResponse

        let counterpartyId = UUID()
        let result = try await sut.fetchExpenses(
            counterpartyId: counterpartyId,
            page: 0,
            limit: 20,
            status: .all,
            cursor: nil
        )
        XCTAssertEqual(result.page, 0)
        XCTAssertFalse(result.hasNext)
        XCTAssertTrue(result.expenses.isEmpty)
    }

    func testFetchNettingWithStoreResolution() async throws {
        let store = FriendDisplayNameStore()
        let repoWithStore = ExpenseRepository(apiClient: apiClient, friendDisplayNameStore: store)

        let counterpartyId = UUID()
        let nettingDTO = NettingSummaryDTO(
            counterparty: ExpenseUserDTO(id: counterpartyId, username: "counterparty", displayName: "Original Name", avatarUrl: nil),
            actorOwesTotal: "300000",
            counterpartyOwesTotal: "100000",
            netAmount: "200000",
            netDirection: "ACTOR_OWES",
            currency: "VND",
            unpaidSplitCount: 2,
            expensesInvolved: 2,
            pendingSettlement: nil
        )
        apiClient.mockResponse = nettingDTO

        let netting = try await repoWithStore.fetchNetting(counterpartyId: counterpartyId)
        XCTAssertEqual(netting.actorOwesTotal, 300000)
        XCTAssertEqual(netting.netDirection, .actorOwes)
        XCTAssertEqual(netting.counterparty.id, counterpartyId)
    }

    func testBulkSettlementFlows() async throws {
        let settlementId = UUID()
        let debtorId = UUID()
        let creditorId = UUID()
        let now = Date()

        let settlementDTO = BulkSettlementDTO(
            id: settlementId,
            debtorUserId: debtorId,
            creditorUserId: creditorId,
            amount: "200000",
            currency: "VND",
            evidenceUrl: "https://example.com/evidence.jpg",
            note: "Paid via bank transfer",
            status: "PENDING_APPROVAL",
            splitCount: 2,
            createdAt: now,
            reviewedAt: nil,
            rejectReason: nil
        )
        apiClient.mockResponse = settlementDTO

        // Submit
        let submitted = try await sut.submitBulkSettlement(
            counterpartyId: creditorId,
            evidenceURL: URL(string: "https://example.com/evidence.jpg")!,
            note: "Paid via bank transfer"
        )
        XCTAssertEqual(submitted.id, settlementId)
        XCTAssertEqual(submitted.status, .pending)

        // Approve
        apiClient.mockResponse = BulkSettlementDTO(
            id: settlementId,
            debtorUserId: debtorId,
            creditorUserId: creditorId,
            amount: "200000",
            currency: "VND",
            evidenceUrl: "https://example.com/evidence.jpg",
            note: nil,
            status: "APPROVED",
            splitCount: 2,
            createdAt: now,
            reviewedAt: now,
            rejectReason: nil
        )
        let approved = try await sut.approveBulkSettlement(id: settlementId)
        XCTAssertEqual(approved.status, .approved)

        // Reject
        apiClient.mockResponse = BulkSettlementDTO(
            id: settlementId,
            debtorUserId: debtorId,
            creditorUserId: creditorId,
            amount: "200000",
            currency: "VND",
            evidenceUrl: "https://example.com/evidence.jpg",
            note: nil,
            status: "REJECTED",
            splitCount: 2,
            createdAt: now,
            reviewedAt: now,
            rejectReason: "Incorrect amount"
        )
        let rejected = try await sut.rejectBulkSettlement(id: settlementId, reason: "Incorrect amount")
        XCTAssertEqual(rejected.status, .rejected)
        XCTAssertEqual(rejected.rejectReason, "Incorrect amount")
    }

    func testClaimBillInvite() async throws {
        let expenseId = UUID()
        let splitId = UUID()
        let postId = UUID()

        let dto = ClaimBillInviteResponseDTO(expenseId: expenseId, postId: postId, splitId: splitId)
        apiClient.mockResponse = dto

        let result = try await sut.claimBillInvite(token: "inv123", splitId: splitId)
        XCTAssertEqual(result.expenseId, expenseId)
        XCTAssertEqual(result.splitId, splitId)
        XCTAssertEqual(result.postId, postId)
    }
}
