import XCTest
import SplickDomain
import Common
import Networking
import Storage
import Localization
@testable import FeatureExpense

final class ExpenseEndpointsAndUseCasesTests: XCTestCase {

    // MARK: - ExpenseEndpoint Tests

    func testExpenseEndpoint_paths() {
        let dummyId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let dummyCounterparty = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!

        XCTAssertEqual(ExpenseEndpoint.list(groupId: nil, page: 0, limit: 20, cursor: nil).path, "/v1/expenses")
        XCTAssertEqual(ExpenseEndpoint.detail(id: dummyId).path, "/v1/expenses/\(dummyId)")
        XCTAssertEqual(ExpenseEndpoint.create(.init(description: "d", totalAmount: "1000", currency: "VND", groupId: nil, category: "GENERAL", splitType: "EQUAL", participants: [], customAmounts: nil)).path, "/v1/expenses")
        XCTAssertEqual(ExpenseEndpoint.settle(expenseId: dummyId, .init(splitId: dummyId)).path, "/v1/expenses/\(dummyId)/settle")
        XCTAssertEqual(ExpenseEndpoint.debtSummary(groupId: nil).path, "/v1/expenses/debts")
        XCTAssertEqual(ExpenseEndpoint.monthlySummary(months: 6).path, "/v1/expenses/monthly-summary")
        XCTAssertEqual(ExpenseEndpoint.overview.path, "/v1/expenses/overview")
        XCTAssertEqual(ExpenseEndpoint.spendingAnalytics(period: .month, months: 3).path, "/v1/expenses/spending-analytics")
        XCTAssertEqual(ExpenseEndpoint.groupSummary.path, "/v1/expenses/group-summary")
        XCTAssertEqual(ExpenseEndpoint.withCounterparty(id: dummyCounterparty, page: 0, limit: 20, status: .all, cursor: nil).path, "/v1/expenses/with-user/\(dummyCounterparty)")
        XCTAssertEqual(ExpenseEndpoint.netting(counterpartyId: dummyCounterparty).path, "/v1/expenses/netting/\(dummyCounterparty)")
        XCTAssertEqual(ExpenseEndpoint.submitBulkSettlement(counterpartyId: dummyCounterparty, .init(evidenceUrl: "url", note: nil)).path, "/v1/expenses/netting/\(dummyCounterparty)/settle")
        XCTAssertEqual(ExpenseEndpoint.approveBulkSettlement(id: dummyId).path, "/v1/expenses/netting/settlements/\(dummyId)/approve")
        XCTAssertEqual(ExpenseEndpoint.rejectBulkSettlement(id: dummyId, .init(reason: "r")).path, "/v1/expenses/netting/settlements/\(dummyId)/reject")
        XCTAssertEqual(ExpenseEndpoint.claimBillInvite(token: "tok123", splitId: nil).path, "/v1/bills/invites/tok123/claim")
    }

    func testExpenseEndpoint_methodsAndQueryItems() {
        let dummyId = UUID()
        let dummyGroupId = UUID()

        XCTAssertEqual(ExpenseEndpoint.list(groupId: nil, page: 0, limit: 20, cursor: nil).method, .get)
        XCTAssertEqual(ExpenseEndpoint.detail(id: dummyId).method, .get)
        XCTAssertEqual(ExpenseEndpoint.create(.init(description: "d", totalAmount: "1000", currency: "VND", groupId: nil, category: "GENERAL", splitType: "EQUAL", participants: [], customAmounts: nil)).method, .post)
        XCTAssertEqual(ExpenseEndpoint.settle(expenseId: dummyId, .init(splitId: dummyId)).method, .post)
        XCTAssertEqual(ExpenseEndpoint.approveBulkSettlement(id: dummyId).method, .post)

        // Query items
        let listWithCursor = ExpenseEndpoint.list(groupId: dummyGroupId, page: 0, limit: 15, cursor: "cur123").queryItems
        XCTAssertNotNil(listWithCursor)
        XCTAssertTrue(listWithCursor!.contains(where: { $0.name == "cursor" && $0.value == "cur123" }))
        XCTAssertTrue(listWithCursor!.contains(where: { $0.name == "groupId" && $0.value == dummyGroupId.uuidString }))

        let debtQuery = ExpenseEndpoint.debtSummary(groupId: dummyGroupId).queryItems
        XCTAssertTrue(debtQuery!.contains(where: { $0.name == "groupId" && $0.value == dummyGroupId.uuidString }))

        let monthlyQuery = ExpenseEndpoint.monthlySummary(months: 12).queryItems
        XCTAssertEqual(monthlyQuery?.first?.name, "months")
        XCTAssertEqual(monthlyQuery?.first?.value, "12")

        let analyticsQuery = ExpenseEndpoint.spendingAnalytics(period: .month, months: 12).queryItems
        XCTAssertEqual(analyticsQuery?.count, 2)

        let counterpartyQuery = ExpenseEndpoint.withCounterparty(id: dummyId, page: 1, limit: 10, status: .open, cursor: nil).queryItems
        XCTAssertTrue(counterpartyQuery!.contains(where: { $0.name == "status" && $0.value == "OPEN" }))
        XCTAssertTrue(counterpartyQuery!.contains(where: { $0.name == "page" && $0.value == "1" }))

        // Body
        XCTAssertNotNil(ExpenseEndpoint.claimBillInvite(token: "tok", splitId: dummyId).body)
        XCTAssertNil(ExpenseEndpoint.claimBillInvite(token: "tok", splitId: nil).body)
        XCTAssertNil(ExpenseEndpoint.overview.body)
    }

    // MARK: - ExpenseMapper Tests

    func testExpenseMapper_toExpense() {
        let expenseId = UUID()
        let userId = UUID()
        let now = Date()
        let dto = ExpenseResponseDTO(
            id: expenseId,
            description: "Team Dinner",
            totalAmount: "250000.5",
            currency: "VND",
            paidBy: ExpenseUserDTO(id: userId, username: "hoan", displayName: "Hoan", avatarUrl: "https://example.com/avatar.jpg"),
            splits: [
                ExpenseSplitDTO(
                    id: UUID(),
                    user: ExpenseUserDTO(id: userId, username: "hoan", displayName: "Hoan", avatarUrl: nil),
                    amount: "125000.25",
                    isPaid: true,
                    paidAt: now,
                    paymentStatus: "PAID",
                    guestDisplayName: nil,
                    inviteUrl: nil
                ),
                ExpenseSplitDTO(
                    id: UUID(),
                    user: nil,
                    amount: "125000.25",
                    isPaid: false,
                    paidAt: nil,
                    paymentStatus: nil,
                    guestDisplayName: "Friend Guest",
                    inviteUrl: nil
                )
            ],
            groupId: nil,
            postId: nil,
            category: "FOOD",
            status: "PENDING",
            createdAt: now,
            settledAt: nil
        )

        let expense = ExpenseMapper.toExpense(dto)
        XCTAssertEqual(expense.id, expenseId)
        XCTAssertEqual(expense.description, "Team Dinner")
        XCTAssertEqual(expense.totalAmount, Decimal(string: "250000.5"))
        XCTAssertEqual(expense.currency, "VND")
        XCTAssertEqual(expense.paidBy.displayName, "Hoan")
        XCTAssertEqual(expense.splits.count, 2)
        XCTAssertEqual(expense.splits[0].paymentStatus, PaymentSplitStatus.paid)
        XCTAssertEqual(expense.splits[1].user.displayName, "Friend Guest")
        XCTAssertEqual(expense.category, ExpenseCategory.food)
        XCTAssertEqual(expense.status, ExpenseStatus.pending)
    }

    func testExpenseMapper_toDebtAndNettingSummary() throws {
        let userDto = ExpenseUserDTO(id: UUID(), username: "bob", displayName: "Bob", avatarUrl: nil)
        let debtDto = DebtSummaryDTO(user: userDto, amount: "50000", currency: "VND")
        let debt = ExpenseMapper.toDebtSummary(debtDto)
        XCTAssertEqual(debt.amount, Decimal(50000))
        XCTAssertEqual(debt.currency, "VND")

        let now = Date()
        let settlementDto = BulkSettlementDTO(
            id: UUID(),
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: "100000",
            currency: "VND",
            evidenceUrl: "https://example.com/receipt.jpg",
            note: "Paid via bank",
            status: "PENDING_APPROVAL",
            splitCount: 3,
            createdAt: now,
            reviewedAt: nil,
            rejectReason: nil
        )

        let nettingDto = NettingSummaryDTO(
            counterparty: userDto,
            actorOwesTotal: "100000",
            counterpartyOwesTotal: "40000",
            netAmount: "60000",
            netDirection: "ACTOR_OWES",
            currency: "VND",
            unpaidSplitCount: 2,
            expensesInvolved: 2,
            pendingSettlement: settlementDto
        )

        let netting = try ExpenseMapper.toNettingSummary(nettingDto)
        XCTAssertEqual(netting.actorOwesTotal, Decimal(100000))
        XCTAssertEqual(netting.counterpartyOwesTotal, Decimal(40000))
        XCTAssertEqual(netting.netAmount, Decimal(60000))
        XCTAssertEqual(netting.netDirection, .actorOwes)
        XCTAssertEqual(netting.pendingSettlement?.amount, Decimal(100000))
        XCTAssertEqual(netting.pendingSettlement?.status, .pending)
    }

    func testExpenseMapper_toOverviewAndRecentExpense() {
        let now = Date()
        let userDto = ExpenseUserDTO(id: UUID(), username: "alice", displayName: "Alice", avatarUrl: nil)
        let overviewDto = ExpenseOverviewDTO(
            balance: ExpenseBalanceSectionDTO(
                youOwe: "10000",
                owedToYou: "20000",
                netBalance: "10000",
                currency: "VND",
                topBalances: []
            ),
            needsAttention: ExpenseNeedsAttentionSectionDTO(
                pendingPaymentRequestCount: 1,
                expensesNeedingConfirmationCount: 0,
                outstandingSettlementCount: 0,
                totalActionItems: 1,
                items: [
                    ExpenseNeedsAttentionItemDTO(
                        type: "PAYMENT_REQUEST",
                        id: UUID(),
                        title: "Coffee",
                        amount: "35000",
                        currency: "VND",
                        counterparty: userDto,
                        createdAt: now,
                        postId: nil
                    )
                ]
            ),
            recentExpenses: [
                RecentExpenseItemDTO(
                    id: UUID(),
                    description: "Taxi",
                    amount: "60000",
                    currency: "VND",
                    category: "TRANSPORT",
                    paidBy: userDto,
                    participants: [userDto],
                    createdAt: now,
                    groupId: nil
                )
            ],
            totalSpending: ExpenseTotalSpendingSectionDTO(
                currentPeriodTotal: "500000",
                previousPeriodTotal: "450000",
                percentageChange: "11.1",
                currency: "VND"
            )
        )

        let overview = ExpenseMapper.toOverview(overviewDto)
        XCTAssertEqual(overview.balance.youOwe, Decimal(10000))
        XCTAssertEqual(overview.balance.owedToYou, Decimal(20000))
        XCTAssertEqual(overview.needsAttention.totalActionItems, 1)
        XCTAssertEqual(overview.needsAttention.items.first?.type, .paymentRequest)
        XCTAssertEqual(overview.recentExpenses.first?.category, ExpenseCategory.transport)
        XCTAssertEqual(overview.totalSpending.currentPeriodTotal, Decimal(500000))
    }

    func testExpenseMapper_toSpendingAnalyticsAndGroupSummary() {
        let now = Date()
        let analyticsDto = SpendingAnalyticsDTO(
            trend: [
                SpendingTrendPointDTO(bucketStart: now, amount: "100000")
            ],
            categories: [
                SpendingCategoryBreakdownDTO(category: "FOOD", amount: "50000", percentage: "50")
            ],
            currency: "VND"
        )
        let analytics = ExpenseMapper.toSpendingAnalytics(analyticsDto)
        XCTAssertEqual(analytics.trend.count, 1)
        XCTAssertEqual(analytics.categories.first?.category, ExpenseCategory.food)

        let groupDto = GroupExpenseSummaryDTO(
            groups: [
                GroupExpenseItemDTO(
                    groupId: UUID(),
                    groupName: "Roommates",
                    groupAvatarUrl: "https://example.com/group.jpg",
                    totalGroupSpending: "1200000",
                    userPaidTotal: "600000",
                    userBalance: "0",
                    currency: "VND",
                    memberAvatars: []
                )
            ]
        )
        let groupSummary = ExpenseMapper.toGroupSummary(groupDto)
        XCTAssertEqual(groupSummary.groups.count, 1)
        XCTAssertEqual(groupSummary.groups.first?.groupName, "Roommates")
    }

    func testExpenseMapper_toRequestDTO() {
        let p1 = UUID()
        let p2 = UUID()
        let req1 = CreateExpenseRequest(
            description: "Lunch",
            totalAmount: 100000,
            currency: "VND",
            groupId: nil,
            category: .food,
            splitType: .equal,
            participants: [p1, p2],
            customAmounts: nil
        )
        let dto1 = ExpenseMapper.toRequestDTO(req1)
        XCTAssertEqual(dto1.description, "Lunch")
        XCTAssertEqual(dto1.category, "FOOD")
        XCTAssertEqual(dto1.splitType, "EQUAL")
        XCTAssertNil(dto1.customAmounts)

        let req2 = CreateExpenseRequest(
            description: "Custom split",
            totalAmount: 100000,
            currency: "VND",
            groupId: nil,
            category: .general,
            splitType: .exact,
            participants: [p1, p2],
            customAmounts: [p1: 60000, p2: 40000]
        )
        let dto2 = ExpenseMapper.toRequestDTO(req2)
        XCTAssertNotNil(dto2.customAmounts)
        XCTAssertEqual(dto2.customAmounts?[p1.uuidString], "60000")
    }

    func testExpenseMapper_errorsAndFallbacks() {
        // Invalid evidence URL
        let invalidUrlDto = BulkSettlementDTO(
            id: UUID(),
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: "100",
            currency: "VND",
            evidenceUrl: "",
            note: nil,
            status: "PENDING_APPROVAL",
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
        XCTAssertThrowsError(try ExpenseMapper.toBulkSettlement(invalidUrlDto))

        // Invalid status
        let invalidStatusDto = BulkSettlementDTO(
            id: UUID(),
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: "100",
            currency: "VND",
            evidenceUrl: "https://example.com/receipt.jpg",
            note: nil,
            status: "INVALID_STATUS_XYZ",
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
        XCTAssertThrowsError(try ExpenseMapper.toBulkSettlement(invalidStatusDto))

        // SplitType display names
        XCTAssertEqual(SplitType.equal.displayName, "Split Equally")
        XCTAssertEqual(SplitType.exact.displayName, "Exact Amounts")
        XCTAssertEqual(SplitType.percentage.displayName, "By Percentage")
    }

    // MARK: - UseCases Tests

    func testExpenseUseCases_executions() async throws {
        let repo = MockAllExpensesRepository()

        // FetchExpensesUseCase
        let fetchExpensesUseCase = FetchExpensesUseCase(repository: repo, pageSize: 10)
        let expenses = try await fetchExpensesUseCase.execute(groupId: nil, page: 0)
        XCTAssertEqual(expenses.count, 1)

        // FetchMonthlySummaryUseCase
        let monthlyUseCase = FetchMonthlySummaryUseCase(repository: repo)
        let monthly = try await monthlyUseCase.execute(months: 6)
        XCTAssertEqual(monthly.currency, "VND")

        // FetchExpenseOverviewUseCase
        let overviewUseCase = FetchExpenseOverviewUseCase(repository: repo)
        let overview = try await overviewUseCase.execute()
        XCTAssertEqual(overview.balance.currency, "VND")

        // FetchSpendingAnalyticsUseCase
        let analyticsUseCase = FetchSpendingAnalyticsUseCase(repository: repo)
        let analytics = try await analyticsUseCase.execute(period: .month, months: 3)
        XCTAssertEqual(analytics.currency, "VND")

        // FetchGroupExpenseSummaryUseCase
        let groupSummaryUseCase = FetchGroupExpenseSummaryUseCase(repository: repo)
        let groupSummary = try await groupSummaryUseCase.execute()
        XCTAssertEqual(groupSummary.groups.count, 0)

        // FetchCounterpartyExpensesUseCase
        let counterpartyExpensesUseCase = FetchCounterpartyExpensesUseCase(repository: repo, pageSize: 10)
        let page = try await counterpartyExpensesUseCase.execute(counterpartyId: UUID(), page: 0)
        XCTAssertEqual(page.page, 0)

        // FetchNettingSummaryUseCase
        let nettingUseCase = FetchNettingSummaryUseCase(repository: repo)
        let netting = try await nettingUseCase.execute(counterpartyId: UUID())
        XCTAssertEqual(netting.currency, "VND")

        // SubmitBulkSettlementUseCase
        let submitSettlement = SubmitBulkSettlementUseCase(repository: repo)
        let settlement = try await submitSettlement.execute(counterpartyId: UUID(), evidenceURL: URL(string: "https://example.com/receipt.jpg")!, note: "note")
        XCTAssertEqual(settlement.note, "note")

        // ApproveBulkSettlementUseCase
        let approveSettlement = ApproveBulkSettlementUseCase(repository: repo)
        let approved = try await approveSettlement.execute(id: settlement.id)
        XCTAssertEqual(approved.status, .approved)

        // RejectBulkSettlementUseCase
        let rejectSettlement = RejectBulkSettlementUseCase(repository: repo)
        let rejected = try await rejectSettlement.execute(id: settlement.id, reason: "Wrong amount")
        XCTAssertEqual(rejected.status, .rejected)

        // FetchDebtSummaryUseCase
        let debtUseCase = FetchDebtSummaryUseCase(repository: repo)
        let debts = try await debtUseCase.execute(groupId: nil)
        XCTAssertEqual(debts.count, 1)
    }

    // MARK: - ExpenseL10n & CreateExpenseViewModel Tests

    @MainActor
    func testExpenseL10n_and_CreateExpenseViewModel() async {
        let mockDefaults = MockUserDefaultsService()
        let languageService = LanguageService(userDefaults: mockDefaults)

        // ExpenseCategory titles
        for cat in ExpenseCategory.allCases {
            XCTAssertFalse(cat.title(using: languageService).isEmpty)
        }

        // ExpenseDebtFilter titles
        for filter in ExpenseDebtFilter.allCases {
            XCTAssertFalse(filter.title(using: languageService).isEmpty)
            XCTAssertFalse(filter.historyTitle(using: languageService).isEmpty)
        }

        // SplitType titles
        for split in SplitType.allCases {
            XCTAssertFalse(split.title(using: languageService).isEmpty)
        }

        // CreateExpenseViewModel validation
        let repo = MockAllExpensesRepository()
        let createUseCase = CreateExpenseUseCase(repository: repo)
        let vm = CreateExpenseViewModel(createExpenseUseCase: createUseCase, languageService: languageService)

        // Empty validation
        await vm.createExpense()
        XCTAssertNotNil(vm.descriptionError)

        // Invalid amount
        vm.description = "Dinner"
        vm.amount = "0"
        await vm.createExpense()
        XCTAssertNotNil(vm.amountError)

        // Amount below minimum
        vm.amount = "500"
        await vm.createExpense()
        XCTAssertNotNil(vm.amountError)

        // Empty participants
        vm.amount = "100000"
        await vm.createExpense()
        if case .failed = vm.state {
            // Expected
        } else {
            XCTFail("Expected failed state due to no participants")
        }

        // Valid create
        vm.selectedParticipants = [UUID()]
        await vm.createExpense()
        if case .loaded(let expense) = vm.state {
            XCTAssertEqual(expense.description, "Dinner")
        } else {
            XCTFail("Expected loaded expense, got \(vm.state)")
        }
    }
}

// MARK: - Mock Repository

actor MockAllExpensesRepository: ExpenseRepositoryProtocol {
    func fetchExpenses(groupId: UUID?, page: Int, limit: Int, cursor: String?) async throws -> [Expense] {
        [
            Expense(
                id: UUID(),
                description: "Test Expense",
                totalAmount: 100000,
                paidBy: UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil),
                splits: []
            )
        ]
    }

    func fetchExpense(id: UUID) async throws -> Expense {
        Expense(
            id: id,
            description: "Test Expense",
            totalAmount: 100000,
            paidBy: UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil),
            splits: []
        )
    }

    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense {
        Expense(
            id: UUID(),
            description: request.description,
            totalAmount: request.totalAmount,
            paidBy: UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil),
            splits: [],
            groupId: request.groupId,
            category: request.category
        )
    }

    func settleExpense(expenseId: UUID, splitId: UUID) async throws {}

    func fetchDebtSummary(groupId: UUID?) async throws -> [DebtSummary] {
        [
            DebtSummary(
                user: UserSummary(id: UUID(), username: "debtor", displayName: "Debtor", avatarURL: nil),
                amount: 50000
            )
        ]
    }

    func fetchMonthlySummary(months: Int) async throws -> MonthlyExpenseSummary {
        let month = MonthData(year: 2026, month: 1, totalSettledReceived: 0, totalSettledPaid: 0)
        return MonthlyExpenseSummary(currency: "VND", currentMonth: month, months: [month])
    }

    func fetchOverview() async throws -> ExpenseOverview {
        ExpenseOverview(
            balance: ExpenseBalanceSection(youOwe: 0, owedToYou: 0, netBalance: 0, currency: "VND", topBalances: []),
            needsAttention: ExpenseNeedsAttentionSection(pendingPaymentRequestCount: 0, expensesNeedingConfirmationCount: 0, outstandingSettlementCount: 0, totalActionItems: 0, items: []),
            recentExpenses: [],
            totalSpending: ExpenseTotalSpendingSection(currentPeriodTotal: 0, previousPeriodTotal: 0, percentageChange: 0, currency: "VND")
        )
    }

    func fetchSpendingAnalytics(period: SpendingAnalyticsPeriod, months: Int) async throws -> SpendingAnalytics {
        SpendingAnalytics(trend: [], categories: [], currency: "VND")
    }

    func fetchGroupExpenseSummary() async throws -> GroupExpenseSummary {
        GroupExpenseSummary(groups: [])
    }

    func fetchExpenses(
        counterpartyId: UUID,
        page: Int,
        limit: Int,
        status: CounterpartyExpenseStatus,
        cursor: String?
    ) async throws -> ExpensePage {
        ExpensePage(expenses: [], page: page, totalPages: 1, totalItems: 0, hasNext: false)
    }

    func fetchNetting(counterpartyId: UUID) async throws -> NettingSummary {
        NettingSummary(
            counterparty: UserSummary(id: counterpartyId, username: "c", displayName: "C", avatarURL: nil),
            actorOwesTotal: 0,
            counterpartyOwesTotal: 0,
            netAmount: 0,
            netDirection: .settled,
            currency: "VND",
            unpaidSplitCount: 0,
            expensesInvolved: 0,
            pendingSettlement: nil
        )
    }

    func submitBulkSettlement(counterpartyId: UUID, evidenceURL: URL, note: String?) async throws -> BulkSettlement {
        BulkSettlement(
            id: UUID(),
            debtorUserId: UUID(),
            creditorUserId: counterpartyId,
            amount: 50000,
            currency: "VND",
            evidenceURL: evidenceURL,
            note: note,
            status: .pending,
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
    }

    func approveBulkSettlement(id: UUID) async throws -> BulkSettlement {
        BulkSettlement(
            id: id,
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: 50000,
            currency: "VND",
            evidenceURL: URL(string: "https://example.com/receipt.jpg")!,
            note: nil,
            status: .approved,
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: Date(),
            rejectReason: nil
        )
    }

    func rejectBulkSettlement(id: UUID, reason: String?) async throws -> BulkSettlement {
        BulkSettlement(
            id: id,
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: 50000,
            currency: "VND",
            evidenceURL: URL(string: "https://example.com/receipt.jpg")!,
            note: nil,
            status: .rejected,
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: Date(),
            rejectReason: reason
        )
    }

    func claimBillInvite(token: String, splitId: UUID?) async throws -> ClaimBillInviteResult {
        ClaimBillInviteResult(expenseId: UUID(), postId: nil, splitId: splitId ?? UUID())
    }
}

// MARK: - Mock User Defaults

final class MockUserDefaultsService: UserDefaultsServiceProtocol, @unchecked Sendable {
    private var store: [String: Any] = [:]

    func set<T: Codable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            store[key] = data
        }
    }

    func get<T: Codable>(for key: String) -> T? {
        guard let data = store[key] as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setBool(_ value: Bool, for key: String) {
        store[key] = value
    }

    func getBool(for key: String) -> Bool {
        store[key] as? Bool ?? false
    }

    func remove(for key: String) {
        store.removeValue(forKey: key)
    }
}

@MainActor
final class ExpenseListViewModelTests: XCTestCase {
    private var repo: MockAllExpensesRepository!
    private var languageService: LanguageService!
    private var currentUserId: UUID!

    override func setUp() {
        super.setUp()
        repo = MockAllExpensesRepository()
        let defaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: defaults)
        currentUserId = UUID()
    }

    func testExpenseListViewModelFlow() async {
        let fetchExpenses = FetchExpensesUseCase(repository: repo)
        let fetchDebt = FetchDebtSummaryUseCase(repository: repo)
        let fetchMonthly = FetchMonthlySummaryUseCase(repository: repo)

        let vm = ExpenseListViewModel(
            fetchExpensesUseCase: fetchExpenses,
            fetchDebtSummaryUseCase: fetchDebt,
            fetchMonthlySummaryUseCase: fetchMonthly,
            languageService: languageService,
            currentUserId: currentUserId
        )

        XCTAssertEqual(vm.expenses.count, 0)
        XCTAssertEqual(vm.totalOwed, Decimal.zero)
        XCTAssertEqual(vm.totalOwing, Decimal.zero)
        XCTAssertFalse(vm.filterSignature.isEmpty)

        // Load expenses
        await vm.load(isPullToRefresh: true)
        XCTAssertEqual(vm.expenses.count, 1)
        XCTAssertEqual(vm.debts.count, 1)
        XCTAssertEqual(vm.totalOwed, Decimal(50000))

        // Test update current user
        let newUserId = UUID()
        vm.updateCurrentUserId(newUserId)
        XCTAssertEqual(vm.currentUserId, newUserId)

        // Refresh badge counts
        await vm.refreshBadgeCounts()
        await vm.softSyncDirectory()

        // Filter and preset methods
        vm.setCaptionQuery("Dinner")
        XCTAssertEqual(vm.filters.captionQuery, "Dinner")

        vm.setDebtStatus(.oweUnpaid)
        XCTAssertEqual(vm.filters.debtStatus, .oweUnpaid)
        vm.setDebtStatus(.oweUnpaid) // toggle back
        XCTAssertEqual(vm.filters.debtStatus, .all)

        vm.applyOverviewDebtFilter(.owedUnpaid)
        XCTAssertEqual(vm.filters.debtStatus, .owedUnpaid)

        let testUser = UserSummary(id: UUID(), username: "u", displayName: "User", avatarURL: nil)
        vm.setSelectedUser(testUser)
        XCTAssertEqual(vm.filters.selectedUsers.count, 1)

        vm.setPeopleFilter(users: [testUser], groups: [])
        XCTAssertEqual(vm.filters.selectedUsers.count, 1)

        vm.setDateFrom(Date())
        vm.setDateTo(Date())
        XCTAssertNotNil(vm.filters.dateFrom)
        XCTAssertNotNil(vm.filters.dateTo)

        vm.setAdvancedExpanded(true)
        XCTAssertTrue(vm.filters.isAdvancedExpanded)

        vm.clearAdvancedFilters()
        XCTAssertEqual(vm.filters.debtStatus, .all)
        XCTAssertTrue(vm.filters.selectedUsers.isEmpty)

        vm.applyDatePreset(.week)
        XCTAssertEqual(vm.filters.activeDatePreset, .week)
        vm.applyDatePreset(.all)
        XCTAssertEqual(vm.filters.activeDatePreset, .all)
        vm.applyDatePreset(.month)
        XCTAssertEqual(vm.filters.activeDatePreset, .month)

        vm.clearListFilters()
        XCTAssertEqual(vm.filters.captionQuery, "")

        // Computed properties
        _ = vm.filteredExpenses
        _ = vm.filteredDebts
        _ = vm.overviewOwedPeopleCount
        _ = vm.overviewOwingPeopleCount
        _ = vm.overviewTotalOwed
        _ = vm.overviewTotalOwing
        _ = vm.overviewOweUnpaidTotal
        _ = vm.overviewOweUnpaidCount
        _ = vm.overviewOwePaidTotal
        _ = vm.overviewOwePaidCount
        _ = vm.overviewOwedUnpaidTotal
        _ = vm.overviewOwedUnpaidCount
        _ = vm.overviewOwedPaidTotal
        _ = vm.overviewOwedPaidCount
        _ = vm.todayOweUnpaidTotal
        _ = vm.todayOwedUnpaidTotal
        _ = vm.todayNetUnpaid
        _ = vm.currentMonthReceived
        _ = vm.currentMonthPaid
        _ = vm.chartData
        _ = vm.monthlySummaryCurrency
        _ = vm.filterParticipantUsers

        // Load more
        await vm.loadMore()
    }
}
