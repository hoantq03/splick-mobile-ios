import XCTest
import Common
import Localization
import SplickDomain
@testable import FeatureExpense

@MainActor
final class ExpenseComprehensiveCoverageTests: XCTestCase {

    // MARK: - ExpenseContentSegment Tests

    func testExpenseContentSegment() {
        XCTAssertEqual(ExpenseContentSegment.allCases.count, 3)
        for segment in ExpenseContentSegment.allCases {
            XCTAssertEqual(segment.id, segment.rawValue)
        }
        XCTAssertEqual(expenseSegmentStripOrder, [.history, .overview, .friends])
    }

    // MARK: - ExpenseListCursor Tests

    func testExpenseListCursorEncoding() {
        let fixedDateWithZeros = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let cursor1 = ExpenseListCursor.encode(createdAt: fixedDateWithZeros, expenseId: id)
        XCTAssertFalse(cursor1.isEmpty)

        let dateWithFraction = Date(timeIntervalSince1970: 1_700_000_000.123)
        let cursor2 = ExpenseListCursor.encode(createdAt: dateWithFraction, expenseId: id)
        XCTAssertFalse(cursor2.isEmpty)
        XCTAssertNotEqual(cursor1, cursor2)
    }

    // MARK: - ExpenseDTOs Tests

    func testExpensePageResponseDTOProperties() {
        let pageWithCursor = ExpensePageResponseDTO<String>(
            content: ["a", "b"],
            page: 0,
            limit: 10,
            totalElements: 100,
            totalPages: 10,
            nextCursor: "cursor123"
        )
        XCTAssertTrue(pageWithCursor.hasNext)
        XCTAssertEqual(pageWithCursor.clampedTotalElements, 100)

        let pageWithoutCursorHasNext = ExpensePageResponseDTO<String>(
            content: ["a"],
            page: 0,
            limit: 10,
            totalElements: -5,
            totalPages: 2,
            nextCursor: nil
        )
        XCTAssertTrue(pageWithoutCursorHasNext.hasNext)
        XCTAssertEqual(pageWithoutCursorHasNext.clampedTotalElements, 0)

        let pageLastPage = ExpensePageResponseDTO<String>(
            content: ["a"],
            page: 1,
            limit: 10,
            totalElements: 20,
            totalPages: 2,
            nextCursor: ""
        )
        XCTAssertFalse(pageLastPage.hasNext)

        let pageZeroTotal = ExpensePageResponseDTO<String>(
            content: [],
            page: 0,
            limit: 10,
            totalElements: 0,
            totalPages: 0,
            nextCursor: nil
        )
        XCTAssertFalse(pageZeroTotal.hasNext)
    }

    // MARK: - ExpenseMapper Tests

    func testExpenseMapperEdgeCases() {
        // Fallbacks on invalid category / status / amount
        let dto = ExpenseResponseDTO(
            id: UUID(),
            description: "Dinner",
            totalAmount: "invalid_decimal",
            currency: "VND",
            paidBy: ExpenseUserDTO(id: nil, username: nil, displayName: "Anon", avatarUrl: "invalid url"),
            splits: [
                ExpenseSplitDTO(
                    id: UUID(),
                    user: nil,
                    amount: "not_a_num",
                    isPaid: false,
                    paidAt: nil,
                    paymentStatus: "invalid_status",
                    guestDisplayName: nil,
                    inviteUrl: nil
                )
            ],
            groupId: nil,
            postId: nil,
            category: "INVALID_CAT",
            status: "INVALID_STATUS",
            createdAt: Date(),
            settledAt: nil
        )

        let expense = ExpenseMapper.toExpense(dto)
        XCTAssertEqual(expense.totalAmount, 0)
        XCTAssertEqual(expense.category, .general)
        XCTAssertEqual(expense.status, .pending)
        XCTAssertEqual(expense.paidBy.username, "user")
        XCTAssertEqual(expense.splits.first?.amount, 0)
        XCTAssertEqual(expense.splits.first?.user.displayName, "Guest")
        XCTAssertEqual(expense.splits.first?.paymentStatus, .unpaid)

        // Split with user and valid status
        let splitWithUser = ExpenseSplitDTO(
            id: UUID(),
            user: ExpenseUserDTO(id: UUID(), username: "john", displayName: "John", avatarUrl: "https://example.com/avatar.png"),
            amount: "1000",
            isPaid: true,
            paidAt: Date(),
            paymentStatus: "paid",
            guestDisplayName: nil,
            inviteUrl: nil
        )
        let mappedSplit = ExpenseMapper.toExpenseSplit(splitWithUser)
        XCTAssertEqual(mappedSplit.user.username, "john")
        XCTAssertEqual(mappedSplit.amount, 1000)
        XCTAssertEqual(mappedSplit.paymentStatus, .paid)

        // NettingSummary invalid direction
        let nettingDTO = NettingSummaryDTO(
            counterparty: ExpenseUserDTO(id: UUID(), username: "cp", displayName: "CP", avatarUrl: nil),
            actorOwesTotal: "invalid",
            counterpartyOwesTotal: "invalid",
            netAmount: "invalid",
            netDirection: "UNKNOWN_DIRECTION",
            currency: "VND",
            unpaidSplitCount: 0,
            expensesInvolved: 0,
            pendingSettlement: nil
        )
        let netting = try? ExpenseMapper.toNettingSummary(nettingDTO)
        XCTAssertEqual(netting?.netDirection, .settled)
        XCTAssertEqual(netting?.netAmount, .zero)

        // BulkSettlement with invalid URL throws
        let invalidURLSettlementDTO = BulkSettlementDTO(
            id: UUID(),
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: "100",
            currency: "VND",
            evidenceUrl: "",
            note: nil,
            status: "PENDING",
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
        XCTAssertThrowsError(try ExpenseMapper.toBulkSettlement(invalidURLSettlementDTO))

        // BulkSettlement with invalid status throws
        let invalidStatusSettlementDTO = BulkSettlementDTO(
            id: UUID(),
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: "100",
            currency: "VND",
            evidenceUrl: "https://example.com/receipt.jpg",
            note: nil,
            status: "INVALID_STATUS",
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
        XCTAssertThrowsError(try ExpenseMapper.toBulkSettlement(invalidStatusSettlementDTO))

        // NeedsAttentionItem fallback
        let attentionDTO = ExpenseNeedsAttentionItemDTO(
            type: "UNKNOWN_TYPE",
            id: UUID(),
            title: "Action",
            amount: "invalid",
            currency: "VND",
            counterparty: nil,
            createdAt: Date(),
            postId: nil
        )
        let attentionItem = ExpenseMapper.toNeedsAttentionItem(attentionDTO)
        XCTAssertEqual(attentionItem.type, .paymentRequest)
        XCTAssertEqual(attentionItem.amount, .zero)

        // RecentExpenseItem fallback
        let recentDTO = RecentExpenseItemDTO(
            id: UUID(),
            description: "Coffee",
            amount: "invalid",
            currency: "VND",
            category: "UNKNOWN_CAT",
            paidBy: ExpenseUserDTO(id: UUID(), username: "p", displayName: "P", avatarUrl: nil),
            participants: [],
            createdAt: Date(),
            groupId: nil
        )
        let recent = ExpenseMapper.toRecentExpense(recentDTO)
        XCTAssertEqual(recent.category, .general)
        XCTAssertEqual(recent.amount, .zero)

        // SpendingAnalytics fallback
        let analyticsDTO = SpendingAnalyticsDTO(
            trend: [SpendingTrendPointDTO(bucketStart: Date(), amount: "invalid")],
            categories: [SpendingCategoryBreakdownDTO(category: "UNKNOWN", amount: "invalid", percentage: "invalid")],
            currency: "VND"
        )
        let analytics = ExpenseMapper.toSpendingAnalytics(analyticsDTO)
        XCTAssertEqual(analytics.trend.first?.amount, .zero)
        XCTAssertEqual(analytics.categories.first?.category, .general)
        XCTAssertEqual(analytics.categories.first?.amount, .zero)

        // CreateExpenseRequestDTO without customAmounts
        let reqNoCustom = CreateExpenseRequest(
            description: "Lunch",
            totalAmount: 50000,
            currency: "VND",
            groupId: nil,
            category: .food,
            splitType: .equal,
            participants: [UUID()]
        )
        let dtoNoCustom = ExpenseMapper.toRequestDTO(reqNoCustom)
        XCTAssertNil(dtoNoCustom.customAmounts)
        XCTAssertEqual(dtoNoCustom.description, "Lunch")
    }

    // MARK: - ExpenseListFilters & ExpenseDebtFilter Tests

    func testExpenseDebtFilterCasesAndMatching() {
        XCTAssertEqual(ExpenseDebtFilter.allCases.count, 8)
        XCTAssertEqual(ExpenseDebtFilter.historyCases.count, 5)

        for filter in ExpenseDebtFilter.allCases {
            XCTAssertEqual(filter.id, filter.rawValue)
        }

        XCTAssertNil(ExpenseDebtFilter.all.matchingDebtState)
        XCTAssertNil(ExpenseDebtFilter.pendingApproval.matchingDebtState)
        XCTAssertNil(ExpenseDebtFilter.awaitingMyReview.matchingDebtState)
        XCTAssertNil(ExpenseDebtFilter.repaid.matchingDebtState)
        XCTAssertEqual(ExpenseDebtFilter.oweUnpaid.matchingDebtState, .oweUnpaid)
        XCTAssertEqual(ExpenseDebtFilter.owePaid.matchingDebtState, .owePaid)
        XCTAssertEqual(ExpenseDebtFilter.owedUnpaid.matchingDebtState, .owedUnpaid)
        XCTAssertEqual(ExpenseDebtFilter.owedPaid.matchingDebtState, .owedPaid)

        let userId = UUID()
        let payer = UserSummary(id: userId, username: "me", displayName: "Me")
        let friend = UserSummary(id: UUID(), username: "friend", displayName: "Friend")

        // Expense where actor is paidBy, friend owes (owedUnpaid)
        let expenseOwedUnpaid = Expense(
            id: UUID(),
            description: "Lunch",
            totalAmount: 100000,
            currency: "VND",
            paidBy: payer,
            splits: [
                ExpenseSplit(id: UUID(), user: payer, amount: 50000, isPaid: true, paymentStatus: .paid),
                ExpenseSplit(id: UUID(), user: friend, amount: 50000, isPaid: false, paymentStatus: .unpaid)
            ]
        )

        XCTAssertTrue(ExpenseDebtFilter.all.matches(expense: expenseOwedUnpaid, userId: userId))
        XCTAssertTrue(ExpenseDebtFilter.owedUnpaid.matches(expense: expenseOwedUnpaid, userId: userId))
        XCTAssertFalse(ExpenseDebtFilter.oweUnpaid.matches(expense: expenseOwedUnpaid, userId: userId))
        XCTAssertFalse(ExpenseDebtFilter.owePaid.matches(expense: expenseOwedUnpaid, userId: userId))
        XCTAssertFalse(ExpenseDebtFilter.owedPaid.matches(expense: expenseOwedUnpaid, userId: userId))
        XCTAssertFalse(ExpenseDebtFilter.pendingApproval.matches(expense: expenseOwedUnpaid, userId: userId))
        XCTAssertFalse(ExpenseDebtFilter.awaitingMyReview.matches(expense: expenseOwedUnpaid, userId: userId))
        XCTAssertFalse(ExpenseDebtFilter.repaid.matches(expense: expenseOwedUnpaid, userId: userId))

        // Expense where friend paid, actor owes and is unpaid
        let expenseOweUnpaid = Expense(
            id: UUID(),
            description: "Dinner",
            totalAmount: 100000,
            currency: "VND",
            paidBy: friend,
            splits: [
                ExpenseSplit(id: UUID(), user: payer, amount: 50000, isPaid: false, paymentStatus: .unpaid),
                ExpenseSplit(id: UUID(), user: friend, amount: 50000, isPaid: true, paymentStatus: .paid)
            ]
        )
        XCTAssertTrue(ExpenseDebtFilter.oweUnpaid.matches(expense: expenseOweUnpaid, userId: userId))
        XCTAssertFalse(ExpenseDebtFilter.owedUnpaid.matches(expense: expenseOweUnpaid, userId: userId))

        // Expense where actor repaid
        let expenseRepaid = Expense(
            id: UUID(),
            description: "Coffee",
            totalAmount: 50000,
            currency: "VND",
            paidBy: friend,
            splits: [
                ExpenseSplit(id: UUID(), user: payer, amount: 50000, isPaid: true, paymentStatus: .paid)
            ]
        )
        XCTAssertTrue(ExpenseDebtFilter.owePaid.matches(expense: expenseRepaid, userId: userId))
        XCTAssertTrue(ExpenseDebtFilter.repaid.matches(expense: expenseRepaid, userId: userId))

        // Expense fully paid where actor was payer
        let expenseActorPaidAll = Expense(
            id: UUID(),
            description: "Taxi",
            totalAmount: 50000,
            currency: "VND",
            paidBy: payer,
            splits: [
                ExpenseSplit(id: UUID(), user: friend, amount: 50000, isPaid: true, paymentStatus: .paid)
            ]
        )
        XCTAssertTrue(ExpenseDebtFilter.owedPaid.matches(expense: expenseActorPaidAll, userId: userId))
    }

    func testExpenseListFiltersComputedProperties() {
        var filters = ExpenseListFilters()
        XCTAssertFalse(filters.hasCaptionSearch)
        XCTAssertFalse(filters.hasPeopleFilter)
        XCTAssertTrue(filters.hasAdvancedFilters)
        XCTAssertTrue(filters.hasAnyFilter)
        XCTAssertTrue(filters.isDefaultDateFilter)
        XCTAssertFalse(filters.hasNonDefaultListFilters)
        XCTAssertEqual(filters.activeDatePreset, .month)

        // Clear dateFrom to test without advanced filters
        var emptyDateFilters = ExpenseListFilters()
        emptyDateFilters.dateFrom = nil
        XCTAssertFalse(emptyDateFilters.hasAdvancedFilters)
        XCTAssertFalse(emptyDateFilters.hasAnyFilter)

        // Caption search
        filters.captionQuery = "Party"
        XCTAssertTrue(filters.hasCaptionSearch)
        XCTAssertTrue(filters.hasAnyFilter)
        XCTAssertTrue(filters.hasNonDefaultListFilters)

        // Date presets
        filters.dateFrom = nil
        filters.dateTo = nil
        XCTAssertEqual(filters.activeDatePreset, .all)

        filters.dateFrom = nil
        filters.dateTo = Date()
        XCTAssertEqual(filters.activeDatePreset, .week)

        filters.dateFrom = ExpenseListFilters.defaultWeekStart
        filters.dateTo = nil
        XCTAssertEqual(filters.activeDatePreset, .week)

        filters.dateFrom = Date(timeIntervalSince1970: 1_000_000)
        filters.dateTo = nil
        XCTAssertEqual(filters.activeDatePreset, .week)

        filters.dateTo = Date()
        XCTAssertEqual(filters.activeDatePreset, .week)
        XCTAssertFalse(filters.isDefaultDateFilter)

        for preset in ExpenseDatePreset.allCases {
            XCTAssertEqual(preset.id, preset.rawValue)
        }
    }

    // MARK: - CreateExpenseViewModel Validation Tests

    func testCreateExpenseViewModelValidation() async {
        let repo = MockAllExpensesRepository()
        let useCase = CreateExpenseUseCase(repository: repo)
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())
        let vm = CreateExpenseViewModel(
            createExpenseUseCase: useCase,
            languageService: languageService
        )

        // 1. Empty description
        await vm.createExpense()
        XCTAssertNotNil(vm.descriptionError)

        // 2. Invalid amount
        vm.description = "Dinner"
        vm.amount = "abc"
        await vm.createExpense()
        XCTAssertNotNil(vm.amountError)

        // 3. Amount < 0
        vm.amount = "-100"
        await vm.createExpense()
        XCTAssertNotNil(vm.amountError)

        // 4. Amount below minimum
        vm.amount = "500" // < 1,000 VND
        await vm.createExpense()
        XCTAssertNotNil(vm.amountError)

        // 5. No participants
        vm.amount = "50000"
        vm.selectedParticipants = []
        await vm.createExpense()
        guard case .failed = vm.state else {
            return XCTFail("Expected failed state when no participants")
        }

        // 6. Valid creation
        vm.selectedParticipants = [UUID()]
        await vm.createExpense()
        guard case .loaded(let expense) = vm.state else {
            return XCTFail("Expected loaded state on valid creation")
        }
        XCTAssertEqual(expense.description, "Dinner")
    }

    // MARK: - ExpenseOverviewViewModel Tests

    func testExpenseOverviewViewModelFlow() async {
        let repo = MockAllExpensesRepository()
        let overviewUseCase = FetchExpenseOverviewUseCase(repository: repo)
        let analyticsUseCase = FetchSpendingAnalyticsUseCase(repository: repo)
        let groupsUseCase = FetchGroupExpenseSummaryUseCase(repository: repo)
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseOverviewViewModel(
            fetchOverviewUseCase: overviewUseCase,
            fetchAnalyticsUseCase: analyticsUseCase,
            fetchGroupsUseCase: groupsUseCase,
            languageService: languageService
        )

        XCTAssertNil(vm.overview)
        XCTAssertNil(vm.analytics)
        XCTAssertTrue(vm.groups.isEmpty)

        // Initial load
        await vm.load()
        XCTAssertNotNil(vm.overview)
        XCTAssertNotNil(vm.analytics)
        XCTAssertTrue(vm.groups.isEmpty)
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state")
        }

        // loadIfNeeded skips when cached
        await vm.loadIfNeeded()
        XCTAssertNotNil(vm.overview)

        // softSync calls through
        await vm.softSync()
        XCTAssertNotNil(vm.overview)

        // Pull to refresh keeps loaded state
        await vm.load(isPullToRefresh: true)
        XCTAssertNotNil(vm.overview)
    }

    // MARK: - ExpenseOverviewTab Helpers Tests

    func testOverviewNetBalanceTitleKey() {
        XCTAssertEqual(overviewNetBalanceTitleKey(Decimal(100)), .expenseOverviewNetYouGetBack)
        XCTAssertEqual(overviewNetBalanceTitleKey(Decimal(-100)), .expenseOverviewNetYouNeedToPay)
        XCTAssertEqual(overviewNetBalanceTitleKey(Decimal.zero), .expenseOverviewNetEven)
    }

    // MARK: - BulkSettleViewModel Tests

    func testBulkSettleViewModelValidationAndFailure() async {
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())
        let counterpartyId = UUID()
        let repo = MockAllExpensesRepository()
        let submitUseCase = SubmitBulkSettlementUseCase(repository: repo)

        let vm = BulkSettleViewModel(
            counterpartyId: counterpartyId,
            uploadEvidence: { _, _ in URL(string: "https://example.com/evidence.jpg")! },
            submitUseCase: submitUseCase,
            languageService: languageService
        )

        // Submit without evidence
        await vm.submit()
        guard case .failed = vm.state else {
            return XCTFail("Expected failed state when no evidence provided")
        }

        // Select evidence with custom mime
        vm.selectEvidence(data: Data([1, 2, 3]), mimeType: "image/png")
        XCTAssertTrue(vm.hasEvidence)
        XCTAssertEqual(vm.state, BulkSettleViewModel.State.idle)

        // Submit with note and success
        vm.note = "Paid in cash"
        await vm.submit()
        guard case .success = vm.state else {
            return XCTFail("Expected success state")
        }
        XCTAssertNotNil(vm.settlement)
    }

    // MARK: - ExpenseFriendListViewModel Error Paths

    func testExpenseFriendListViewModelErrorPaths() async {
        let failingUseCase = FailingDebtSummaryUseCase()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())
        let vm = ExpenseFriendListViewModel(
            fetchDebtSummaryUseCase: failingUseCase,
            languageService: languageService
        )

        await vm.load()
        guard case .failed = vm.state else {
            return XCTFail("Expected failed state on error")
        }

        // loadIfNeeded does load when not cached
        await vm.loadIfNeeded()
        guard case .failed = vm.state else {
            return XCTFail("Expected failed state")
        }
    }

    // MARK: - ExpenseFriendDetailViewModel Methods

    func testExpenseFriendDetailViewModelMethods() async {
        let friend = UserSummary(id: UUID(), username: "friend", displayName: "Friend", avatarURL: nil)
        let currentUserId = UUID()
        let repo = MockAllExpensesRepository()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseFriendDetailViewModel(
            counterparty: friend,
            currentUserId: currentUserId,
            fetchExpensesUseCase: FetchCounterpartyExpensesUseCase(repository: repo),
            fetchNettingUseCase: FetchNettingSummaryUseCase(repository: repo),
            submitUseCase: SubmitBulkSettlementUseCase(repository: repo),
            approveUseCase: ApproveBulkSettlementUseCase(repository: repo),
            rejectUseCase: RejectBulkSettlementUseCase(repository: repo),
            uploadEvidence: { _, _ in URL(string: "https://example.com/e.jpg")! },
            languageService: languageService
        )

        await vm.load()
        XCTAssertNotNil(vm.summary)
        XCTAssertTrue(vm.expenses.isEmpty)

        // Test youOweExpenses and theyOweExpenses
        _ = vm.youOweExpenses
        _ = vm.theyOweExpenses
        _ = vm.canQuickSettle
        _ = vm.canReviewPendingSettlement
        _ = vm.isPendingSettlementDebtor

        // Make bulk settle VM
        let bulkVM = vm.makeBulkSettleViewModel()
        XCTAssertNotNil(bulkVM)

        // Did submit settlement
        let settlement = BulkSettlement(
            id: UUID(),
            debtorUserId: currentUserId,
            creditorUserId: friend.id,
            amount: 50000,
            currency: "VND",
            evidenceURL: URL(string: "https://example.com/receipt.jpg")!,
            note: nil,
            status: .pending,
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
        vm.didSubmit(settlement)
        XCTAssertEqual(vm.bulkSettlement?.id, settlement.id)

        // Load more when hasNextPage is false does nothing
        await vm.loadMore()

        // Refresh
        await vm.refresh()
        XCTAssertNotNil(vm.summary)
    }

    // MARK: - CreateExpenseViewModel Errors

    func testCreateExpenseViewModelErrors() async {
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        // AppError failure
        let appErrorUseCase = FailingCreateExpenseUseCase(error: AppError.unknown("Network failed"))
        let vmAppError = CreateExpenseViewModel(
            createExpenseUseCase: appErrorUseCase,
            languageService: languageService
        )
        vmAppError.description = "Dinner"
        vmAppError.amount = "50000"
        vmAppError.selectedParticipants = [UUID()]
        await vmAppError.createExpense()
        guard case .failed = vmAppError.state else {
            return XCTFail("Expected failed state on AppError")
        }

        // Generic error failure
        let genericErrorUseCase = FailingCreateExpenseUseCase(error: URLError(.cannotConnectToHost))
        let vmGenericError = CreateExpenseViewModel(
            createExpenseUseCase: genericErrorUseCase,
            languageService: languageService
        )
        vmGenericError.description = "Lunch"
        vmGenericError.amount = "50000"
        vmGenericError.selectedParticipants = [UUID()]
        await vmGenericError.createExpense()
        guard case .failed = vmGenericError.state else {
            return XCTFail("Expected failed state on generic error")
        }
    }

    // MARK: - ExpenseOverviewViewModel Error Paths

    func testExpenseOverviewViewModelErrorPaths() async {
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        // Overview load failure
        let failingOverview = FailingOverviewUseCase()
        let vmFailingOverview = ExpenseOverviewViewModel(
            fetchOverviewUseCase: failingOverview,
            fetchAnalyticsUseCase: FailingAnalyticsUseCase(),
            fetchGroupsUseCase: FailingGroupsUseCase(),
            languageService: languageService
        )
        await vmFailingOverview.load()
        guard case .failed = vmFailingOverview.state else {
            return XCTFail("Expected failed state when overview fails")
        }

        // Overview success but secondary failures
        let repo = MockAllExpensesRepository()
        let vmSecondaryFailing = ExpenseOverviewViewModel(
            fetchOverviewUseCase: FetchExpenseOverviewUseCase(repository: repo),
            fetchAnalyticsUseCase: FailingAnalyticsUseCase(),
            fetchGroupsUseCase: FailingGroupsUseCase(),
            languageService: languageService
        )
        await vmSecondaryFailing.load()
        guard case .loaded = vmSecondaryFailing.state else {
            return XCTFail("Expected overview loaded")
        }
        guard case .failed = vmSecondaryFailing.analyticsState else {
            return XCTFail("Expected analytics failed")
        }
        guard case .failed = vmSecondaryFailing.groupsState else {
            return XCTFail("Expected groups failed")
        }
    }

    // MARK: - ExpenseFriendDetailViewModel Actions

    func testExpenseFriendDetailViewModelActions() async {
        let currentUserId = UUID()
        let friend = UserSummary(id: UUID(), username: "friend", displayName: "Friend", avatarURL: nil)
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())
        let repo = MockAllExpensesRepository()
        let approveUseCase = MockApproveSettlementUseCase()
        let rejectUseCase = MockRejectSettlementUseCase()

        let vm = ExpenseFriendDetailViewModel(
            counterparty: friend,
            currentUserId: currentUserId,
            fetchExpensesUseCase: FetchCounterpartyExpensesUseCase(repository: repo),
            fetchNettingUseCase: FetchNettingSummaryUseCase(repository: repo),
            submitUseCase: SubmitBulkSettlementUseCase(repository: repo),
            approveUseCase: approveUseCase,
            rejectUseCase: rejectUseCase,
            uploadEvidence: { _, _ in URL(string: "https://example.com/e.jpg")! },
            languageService: languageService
        )

        // Load
        await vm.load()

        // Set pending settlement where current user is creditor
        let pendingSettlement = BulkSettlement(
            id: UUID(),
            debtorUserId: friend.id,
            creditorUserId: currentUserId,
            amount: 50000,
            currency: "VND",
            evidenceURL: URL(string: "https://example.com/receipt.jpg")!,
            note: "Paid",
            status: .pending,
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
        vm.didSubmit(pendingSettlement)
        XCTAssertTrue(vm.canReviewPendingSettlement)
        XCTAssertFalse(vm.isPendingSettlementDebtor)

        // Approve settlement success
        await vm.approveSettlement()
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state after approve")
        }

        // Set pending settlement again to test reject
        vm.didSubmit(pendingSettlement)
        await vm.rejectSettlement(reason: "Wrong receipt")
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state after reject")
        }

        // Test approve failure
        approveUseCase.shouldFail = true
        vm.didSubmit(pendingSettlement)
        await vm.approveSettlement()
        guard case .failed = vm.state else {
            return XCTFail("Expected failed state on approve error")
        }

        // Test reject failure
        rejectUseCase.shouldFail = true
        vm.didSubmit(pendingSettlement)
        await vm.rejectSettlement(reason: "Bad")
        guard case .failed = vm.state else {
            return XCTFail("Expected failed state on reject error")
        }
    }

    // MARK: - ExpenseListViewModel Filter Matching & Errors

    func testExpenseListViewModelFilterMatching() async {
        let currentUserId = UUID()
        let friend = UserSummary(id: UUID(), username: "friend", displayName: "Friend", avatarURL: nil)
        let otherUser = UserSummary(id: UUID(), username: "other", displayName: "Other", avatarURL: nil)
        let repo = MockAllExpensesRepository()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseListViewModel(
            fetchExpensesUseCase: FetchExpensesUseCase(repository: repo),
            fetchDebtSummaryUseCase: FetchDebtSummaryUseCase(repository: repo),
            fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCase(repository: repo),
            languageService: languageService,
            currentUserId: currentUserId
        )

        await vm.load()
        await vm.hydrateLocalSnapshotIfNeeded()

        // Filter by user
        vm.setSelectedUser(friend)
        XCTAssertEqual(vm.filters.selectedUsers.count, 1)
        _ = vm.filteredExpenses

        // Filter by date range (past range filters out today's expenses)
        let pastDate = Date(timeIntervalSince1970: 1000)
        vm.setDateFrom(pastDate)
        vm.setDateTo(pastDate.addingTimeInterval(3600))
        _ = vm.filteredExpenses
    }

    func testExpenseListViewModelLoadFailure() async {
        let failingExpenses = FailingExpensesUseCase()
        let repo = MockAllExpensesRepository()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseListViewModel(
            fetchExpensesUseCase: failingExpenses,
            fetchDebtSummaryUseCase: FetchDebtSummaryUseCase(repository: repo),
            languageService: languageService
        )

        await vm.load()
        guard case .failed = vm.state else {
            return XCTFail("Expected failed state on expenses load failure")
        }
    }

    // MARK: - Additional Overview, FriendList & FriendDetail Tests

    func testExpenseOverviewViewModelCancellationAndRefreshFailure() async {
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        // 1. CancellationError leaves state as idle
        let cancelUseCase = CancellationOverviewUseCase()
        let vmCancel = ExpenseOverviewViewModel(
            fetchOverviewUseCase: cancelUseCase,
            fetchAnalyticsUseCase: FailingAnalyticsUseCase(),
            fetchGroupsUseCase: FailingGroupsUseCase(),
            languageService: languageService
        )
        await vmCancel.load()
        guard case .idle = vmCancel.state else {
            return XCTFail("Expected idle state after cancellation")
        }

        // 2. Load success first, then PTR fails but keeps loaded overview
        let dynamicRepo = DynamicOverviewUseCase()
        let vmPTR = ExpenseOverviewViewModel(
            fetchOverviewUseCase: dynamicRepo,
            fetchAnalyticsUseCase: FailingAnalyticsUseCase(),
            fetchGroupsUseCase: FailingGroupsUseCase(),
            languageService: languageService
        )
        await vmPTR.load()
        guard case .loaded = vmPTR.state else {
            return XCTFail("Expected loaded state initially")
        }

        dynamicRepo.shouldFail = true
        await vmPTR.load(isPullToRefresh: true)
        guard case .loaded = vmPTR.state else {
            return XCTFail("Expected loaded state preserved after PTR failure")
        }
    }

    func testExpenseFriendListViewModelPullToRefreshError() async {
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())
        let dynamicUseCase = DynamicDebtSummaryUseCase()
        let vm = ExpenseFriendListViewModel(
            fetchDebtSummaryUseCase: dynamicUseCase,
            languageService: languageService
        )

        // Initial success
        await vm.load()
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertFalse(vm.debts.isEmpty)

        // Cached snapshot skips loadIfNeeded
        await vm.loadIfNeeded()

        // Pull to refresh error preserves loaded state when debts not empty
        dynamicUseCase.shouldFail = true
        await vm.load(isPullToRefresh: true)
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state preserved during PTR error")
        }
    }

    func testBulkSettleViewModelEmptyNoteAndUploadError() async {
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())
        let repo = MockAllExpensesRepository()
        let submitUseCase = SubmitBulkSettlementUseCase(repository: repo)

        // Upload error
        let vmUploadFail = BulkSettleViewModel(
            counterpartyId: UUID(),
            uploadEvidence: { _, _ in throw URLError(.timedOut) },
            submitUseCase: submitUseCase,
            languageService: languageService
        )
        vmUploadFail.selectEvidence(data: Data([1, 2]))
        await vmUploadFail.submit()
        guard case .failed = vmUploadFail.state else {
            return XCTFail("Expected failed state on upload error")
        }

        // Empty note submits nil note
        let vmEmptyNote = BulkSettleViewModel(
            counterpartyId: UUID(),
            uploadEvidence: { _, _ in URL(string: "https://example.com/receipt.jpg")! },
            submitUseCase: submitUseCase,
            languageService: languageService
        )
        vmEmptyNote.selectEvidence(data: Data([1, 2]))
        vmEmptyNote.note = "   "
        await vmEmptyNote.submit()
        guard case .success = vmEmptyNote.state else {
            return XCTFail("Expected success state on empty note")
        }
    }

    func testExpenseFriendDetailViewModelAdvancedCases() async {
        let currentUserId = UUID()
        let friend = UserSummary(id: UUID(), username: "friend", displayName: "Friend", avatarURL: nil)
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())
        let repo = MockAllExpensesRepository()

        let dynamicExpensesUseCase = DynamicCounterpartyExpensesUseCase()
        dynamicExpensesUseCase.currentUserId = currentUserId
        let dynamicNettingUseCase = DynamicNettingUseCase(currentUserId: currentUserId, friendId: friend.id)

        let vm = ExpenseFriendDetailViewModel(
            counterparty: friend,
            currentUserId: currentUserId,
            fetchExpensesUseCase: dynamicExpensesUseCase,
            fetchNettingUseCase: dynamicNettingUseCase,
            submitUseCase: SubmitBulkSettlementUseCase(repository: repo),
            approveUseCase: MockApproveSettlementUseCase(),
            rejectUseCase: MockRejectSettlementUseCase(),
            uploadEvidence: { _, _ in URL(string: "https://example.com/e.jpg")! },
            languageService: languageService
        )

        // Summary actor owes enables quick settle
        dynamicNettingUseCase.direction = .actorOwes
        await vm.load()
        XCTAssertTrue(vm.canQuickSettle)
        XCTAssertFalse(vm.youOweExpenses.isEmpty)
        XCTAssertFalse(vm.theyOweExpenses.isEmpty)

        // Summary counterparty owes disables quick settle
        dynamicNettingUseCase.direction = .counterpartyOwes
        await vm.refresh()
        XCTAssertFalse(vm.canQuickSettle)

        // Summary settled disables quick settle
        dynamicNettingUseCase.direction = .settled
        await vm.refresh()
        XCTAssertFalse(vm.canQuickSettle)

        // Load more failure sets error while hasNextPage is still true
        dynamicExpensesUseCase.shouldFail = true
        await vm.loadMore()
        XCTAssertNotNil(vm.loadMoreError)

        // Load more success with pagination
        dynamicExpensesUseCase.shouldFail = false
        dynamicExpensesUseCase.hasNext = false
        await vm.loadMore()
        XCTAssertNil(vm.loadMoreError)
        XCTAssertFalse(vm.hasNextPage)

        // Pull to refresh error preserves loaded state
        dynamicExpensesUseCase.shouldFail = true
        dynamicNettingUseCase.shouldFail = true
        await vm.refresh()
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state preserved on PTR error")
        }
    }

    func testExpenseListViewModelParticipantUsersAndMoreBranches() async {
        let currentUserId = UUID()
        let u1 = UserSummary(id: UUID(), username: "alice", displayName: "Alice", avatarURL: nil)
        let u2 = UserSummary(id: UUID(), username: "bob", displayName: "Bob", avatarURL: nil)
        let group = SplickDomain.Group(id: UUID(), name: "Trip", inviteCode: "T1", createdBy: currentUserId)

        let expense1 = Expense(
            id: UUID(),
            description: "Flight",
            totalAmount: 200000,
            currency: "VND",
            paidBy: u1,
            splits: [
                ExpenseSplit(id: UUID(), user: u1, amount: 100000, isPaid: true, paymentStatus: .paid),
                ExpenseSplit(id: UUID(), user: u2, amount: 100000, isPaid: false, paymentStatus: .unpaid)
            ],
            groupId: group.id
        )

        let repo = MockAllExpensesRepository()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseListViewModel(
            fetchExpensesUseCase: StubListExpensesUseCase(expenses: [expense1]),
            fetchDebtSummaryUseCase: FetchDebtSummaryUseCase(repository: repo),
            fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCase(repository: repo),
            languageService: languageService,
            currentUserId: currentUserId
        )

        await vm.load()

        // Test filterParticipantUsers contains both Alice and Bob sorted
        let participants = vm.filterParticipantUsers
        XCTAssertEqual(participants.count, 2)
        XCTAssertEqual(participants.first?.displayName, "Alice")
        XCTAssertEqual(participants.last?.displayName, "Bob")

        // Test people filter with group
        vm.setPeopleFilter(users: [], groups: [group])
        XCTAssertEqual(vm.filters.selectedGroups.count, 1)
        _ = vm.filteredExpenses

        // Test user matching on split user
        vm.setPeopleFilter(users: [u2], groups: [])
        _ = vm.filteredExpenses

        // Test user matching on neither
        let u3 = UserSummary(id: UUID(), username: "charlie", displayName: "Charlie", avatarURL: nil)
        vm.setPeopleFilter(users: [u3], groups: [])
        _ = vm.filteredExpenses
    }

    // MARK: - Additional Coverage for Endpoints, Mappers & Snapshots

    func testExpenseEndpointAdditionalBranches() {
        let gid = UUID()
        let epListWithPage = ExpenseEndpoint.list(groupId: gid, page: 3, limit: 15, cursor: nil)
        XCTAssertTrue(epListWithPage.queryItems?.contains { $0.name == "page" && $0.value == "3" } ?? false)
        XCTAssertTrue(epListWithPage.queryItems?.contains { $0.name == "groupId" && $0.value == gid.uuidString } ?? false)

        let epCounterpartyWithCursor = ExpenseEndpoint.withCounterparty(id: UUID(), page: 0, limit: 10, status: .all, cursor: "curs123")
        XCTAssertTrue(epCounterpartyWithCursor.queryItems?.contains { $0.name == "cursor" && $0.value == "curs123" } ?? false)

        let epClaimNilSplit = ExpenseEndpoint.claimBillInvite(token: "T", splitId: nil)
        XCTAssertNil(epClaimNilSplit.body)

        let epCreate = ExpenseEndpoint.create(CreateExpenseRequestDTO(
            description: "Test",
            totalAmount: "100",
            currency: "VND",
            groupId: nil,
            category: "FOOD",
            splitType: "EQUAL",
            participants: [UUID()],
            customAmounts: nil
        ))
        XCTAssertNotNil(epCreate.body)

        let epSettle = ExpenseEndpoint.settle(expenseId: UUID(), SettleExpenseRequestDTO(splitId: UUID()))
        XCTAssertNotNil(epSettle.body)

        let epSubmitBulk = ExpenseEndpoint.submitBulkSettlement(
            counterpartyId: UUID(),
            SubmitBulkSettlementRequestDTO(
                evidenceUrl: "https://example.com/receipt.jpg",
                note: "Note"
            )
        )
        XCTAssertNotNil(epSubmitBulk.body)

        let epRejectBulk = ExpenseEndpoint.rejectBulkSettlement(
            id: UUID(),
            RejectBulkSettlementRequestDTO(reason: "Invalid")
        )
        XCTAssertNotNil(epRejectBulk.body)
    }

    func testExpenseMapperAdditionalBranches() throws {
        let invalidAmountDTO = BulkSettlementDTO(
            id: UUID(),
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: "invalid_decimal_string",
            currency: "VND",
            evidenceUrl: "https://example.com/e.jpg",
            note: nil,
            status: "PENDING_APPROVAL",
            splitCount: 1,
            createdAt: Date(),
            reviewedAt: nil,
            rejectReason: nil
        )
        let mapped = try ExpenseMapper.toBulkSettlement(invalidAmountDTO)
        XCTAssertEqual(mapped.amount, Decimal.zero)

        let req = CreateExpenseRequest(
            description: "Dinner",
            totalAmount: 100000,
            currency: "VND",
            groupId: nil,
            category: .food,
            splitType: .exact,
            participants: [UUID()],
            customAmounts: [UUID(): Decimal(100000)]
        )
        let reqDTO = ExpenseMapper.toRequestDTO(req)
        XCTAssertEqual(reqDTO.customAmounts?.count, 1)
    }

    func testExpenseOverviewSnapshotTotalsAndCounts() {
        var snapshot = ExpenseOverviewSnapshot()
        snapshot.oweUnpaidTotal = 100
        snapshot.oweUnpaidCount = 1
        snapshot.owePaidTotal = 200
        snapshot.owePaidCount = 2
        snapshot.owedUnpaidTotal = 300
        snapshot.owedUnpaidCount = 3
        snapshot.owedPaidTotal = 400
        snapshot.owedPaidCount = 4

        XCTAssertEqual(snapshot.total(for: .oweUnpaid), 100)
        XCTAssertEqual(snapshot.total(for: .owePaid), 200)
        XCTAssertEqual(snapshot.total(for: .owedUnpaid), 300)
        XCTAssertEqual(snapshot.total(for: .owedPaid), 400)
        XCTAssertEqual(snapshot.total(for: .neutral), 0)

        XCTAssertEqual(snapshot.count(for: .oweUnpaid), 1)
        XCTAssertEqual(snapshot.count(for: .owePaid), 2)
        XCTAssertEqual(snapshot.count(for: .owedUnpaid), 3)
        XCTAssertEqual(snapshot.count(for: .owedPaid), 4)
        XCTAssertEqual(snapshot.count(for: .neutral), 0)
    }

    func testExpenseListViewModelAdditionalMethodsAndBranches() async {
        let currentUserId = UUID()
        let repo = MockAllExpensesRepository()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseListViewModel(
            fetchExpensesUseCase: FetchExpensesUseCase(repository: repo),
            fetchDebtSummaryUseCase: FetchDebtSummaryUseCase(repository: repo),
            fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCase(repository: repo),
            languageService: languageService,
            currentUserId: currentUserId
        )

        // Test caption query filter
        vm.setCaptionQuery("groceries")
        XCTAssertEqual(vm.filters.captionQuery, "groceries")

        // Test debt status toggle
        vm.setDebtStatus(.oweUnpaid)
        XCTAssertEqual(vm.filters.debtStatus, .oweUnpaid)
        vm.setDebtStatus(.oweUnpaid)
        XCTAssertEqual(vm.filters.debtStatus, .all)

        // Test loadMore with more pages and cursor
        await vm.load()
        let initialCount = vm.expenses.count
        await vm.loadMore()
        XCTAssertEqual(vm.expenses.count, initialCount)
    }

    func testExpenseOverviewViewModelInFlightAndErrorBranches() async {
        let repo = MockAllExpensesRepository()
        let dynamicOverviewUseCase = DynamicOverviewUseCase()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseOverviewViewModel(
            fetchOverviewUseCase: dynamicOverviewUseCase,
            fetchAnalyticsUseCase: FetchSpendingAnalyticsUseCase(repository: repo),
            fetchGroupsUseCase: FetchGroupExpenseSummaryUseCase(repository: repo),
            languageService: languageService
        )

        // Load initially
        await vm.load()
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state")
        }

        // softSync when cached snapshot exists
        await vm.softSync()

        // Force load failure when overview is already loaded restores loaded state
        dynamicOverviewUseCase.shouldFail = true
        await vm.load(isPullToRefresh: true, force: true)
        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state restored after failure on force reload")
        }
    }

    func testExpenseOverviewViewModelInFlightTaskDeduplication() async {
        let controllableUseCase = ControllableOverviewUseCase()
        let repo = MockAllExpensesRepository()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseOverviewViewModel(
            fetchOverviewUseCase: controllableUseCase,
            fetchAnalyticsUseCase: FetchSpendingAnalyticsUseCase(repository: repo),
            fetchGroupsUseCase: FetchGroupExpenseSummaryUseCase(repository: repo),
            languageService: languageService
        )

        let t1 = Task { await vm.load() }
        try? await Task.sleep(nanoseconds: 30_000_000)

        // loadIfNeeded and load while t1 is in flight
        let t2 = Task { await vm.loadIfNeeded() }
        let t3 = Task { await vm.load() }

        // Finish the load
        controllableUseCase.resume()

        await t1.value
        await t2.value
        await t3.value

        guard case .loaded = vm.state else {
            return XCTFail("Expected loaded state")
        }
    }

    func testExpenseListViewModelPaginationAndSummaryFailures() async {
        let currentUserId = UUID()
        let groupId = UUID()
        let paginatedRepo = PaginatedExpenseRepository()
        let languageService = LanguageService(userDefaults: MockUserDefaultsService())

        let vm = ExpenseListViewModel(
            fetchExpensesUseCase: FetchExpensesUseCase(repository: paginatedRepo),
            fetchDebtSummaryUseCase: FetchDebtSummaryUseCase(repository: paginatedRepo),
            fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCase(repository: paginatedRepo),
            languageService: languageService,
            groupId: groupId,
            currentUserId: currentUserId
        )

        // Initial load returns 20 items
        await vm.load()
        XCTAssertEqual(vm.expenses.count, 20)

        // Load more success
        await vm.loadMore()
        XCTAssertEqual(vm.expenses.count, 40)

        // Load more failure
        paginatedRepo.shouldFail = true
        await vm.loadMore()

        // Cancellation on monthly summary
        let cancelSummaryRepo = MonthlySummaryFailingRepository(error: CancellationError())
        let vmCancel = ExpenseListViewModel(
            fetchExpensesUseCase: FetchExpensesUseCase(repository: cancelSummaryRepo),
            fetchDebtSummaryUseCase: FetchDebtSummaryUseCase(repository: cancelSummaryRepo),
            fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCase(repository: cancelSummaryRepo),
            languageService: languageService,
            currentUserId: currentUserId
        )
        await vmCancel.load(isPullToRefresh: true)

        // Generic error on monthly summary
        let errorSummaryRepo = MonthlySummaryFailingRepository(error: URLError(.cannotConnectToHost))
        let vmError = ExpenseListViewModel(
            fetchExpensesUseCase: FetchExpensesUseCase(repository: errorSummaryRepo),
            fetchDebtSummaryUseCase: FetchDebtSummaryUseCase(repository: errorSummaryRepo),
            fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCase(repository: errorSummaryRepo),
            languageService: languageService,
            currentUserId: currentUserId
        )
        await vmError.load(isPullToRefresh: true)
    }
}

private final class ControllableOverviewUseCase: FetchExpenseOverviewUseCaseProtocol, @unchecked Sendable {
    private var continuation: CheckedContinuation<ExpenseOverview, Error>?
    private let lock = NSLock()

    func execute() async throws -> ExpenseOverview {
        try await withCheckedThrowingContinuation { cont in
            lock.lock()
            self.continuation = cont
            lock.unlock()
        }
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        let overview = ExpenseOverview(
            balance: ExpenseBalanceSection(youOwe: 0, owedToYou: 0, netBalance: 0, currency: "VND", topBalances: []),
            needsAttention: ExpenseNeedsAttentionSection(pendingPaymentRequestCount: 0, expensesNeedingConfirmationCount: 0, outstandingSettlementCount: 0, totalActionItems: 0, items: []),
            recentExpenses: [],
            totalSpending: ExpenseTotalSpendingSection(currentPeriodTotal: 0, previousPeriodTotal: 0, percentageChange: 0, currency: "VND")
        )
        continuation?.resume(returning: overview)
        continuation = nil
    }
}

private final class PaginatedExpenseRepository: ExpenseRepositoryProtocol, @unchecked Sendable {
    var shouldFail = false
    func fetchExpenses(groupId: UUID?, page: Int, limit: Int, cursor: String?) async throws -> [Expense] {
        if shouldFail { throw URLError(.cannotConnectToHost) }
        let user = UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil)
        return (0..<20).map { i in
            Expense(
                id: UUID(),
                description: "Item \(i)",
                totalAmount: 10000,
                currency: "VND",
                paidBy: user,
                splits: [ExpenseSplit(id: UUID(), user: user, amount: 10000, isPaid: true, paymentStatus: .paid)]
            )
        }
    }
    func fetchExpense(id: UUID) async throws -> Expense { fatalError() }
    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense { fatalError() }
    func settleExpense(expenseId: UUID, splitId: UUID) async throws {}
    func fetchDebtSummary(groupId: UUID?) async throws -> [DebtSummary] { [] }
    func fetchMonthlySummary(months: Int) async throws -> MonthlyExpenseSummary {
        let m = MonthData(year: 2026, month: 9, totalSettledReceived: 0, totalSettledPaid: 0)
        return MonthlyExpenseSummary(currency: "VND", currentMonth: m, months: [m])
    }
    func fetchOverview() async throws -> ExpenseOverview { fatalError() }
    func fetchSpendingAnalytics(period: SpendingAnalyticsPeriod, months: Int) async throws -> SpendingAnalytics { fatalError() }
    func fetchGroupExpenseSummary() async throws -> GroupExpenseSummary { GroupExpenseSummary(groups: []) }
    func fetchExpenses(counterpartyId: UUID, page: Int, limit: Int, status: CounterpartyExpenseStatus, cursor: String?) async throws -> ExpensePage { ExpensePage(expenses: [], page: page, totalPages: 1, totalItems: 0, hasNext: false) }
    func fetchNetting(counterpartyId: UUID) async throws -> NettingSummary { fatalError() }
    func submitBulkSettlement(counterpartyId: UUID, evidenceURL: URL, note: String?) async throws -> BulkSettlement { fatalError() }
    func approveBulkSettlement(id: UUID) async throws -> BulkSettlement { fatalError() }
    func rejectBulkSettlement(id: UUID, reason: String?) async throws -> BulkSettlement { fatalError() }
    func claimBillInvite(token: String, splitId: UUID?) async throws -> ClaimBillInviteResult { fatalError() }
}

private final class MonthlySummaryFailingRepository: ExpenseRepositoryProtocol, @unchecked Sendable {
    let error: Error
    init(error: Error) { self.error = error }
    func fetchExpenses(groupId: UUID?, page: Int, limit: Int, cursor: String?) async throws -> [Expense] { [] }
    func fetchExpense(id: UUID) async throws -> Expense { fatalError() }
    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense { fatalError() }
    func settleExpense(expenseId: UUID, splitId: UUID) async throws {}
    func fetchDebtSummary(groupId: UUID?) async throws -> [DebtSummary] { [] }
    func fetchMonthlySummary(months: Int) async throws -> MonthlyExpenseSummary { throw error }
    func fetchOverview() async throws -> ExpenseOverview { fatalError() }
    func fetchSpendingAnalytics(period: SpendingAnalyticsPeriod, months: Int) async throws -> SpendingAnalytics { fatalError() }
    func fetchGroupExpenseSummary() async throws -> GroupExpenseSummary { GroupExpenseSummary(groups: []) }
    func fetchExpenses(counterpartyId: UUID, page: Int, limit: Int, status: CounterpartyExpenseStatus, cursor: String?) async throws -> ExpensePage { ExpensePage(expenses: [], page: page, totalPages: 1, totalItems: 0, hasNext: false) }
    func fetchNetting(counterpartyId: UUID) async throws -> NettingSummary { fatalError() }
    func submitBulkSettlement(counterpartyId: UUID, evidenceURL: URL, note: String?) async throws -> BulkSettlement { fatalError() }
    func approveBulkSettlement(id: UUID) async throws -> BulkSettlement { fatalError() }
    func rejectBulkSettlement(id: UUID, reason: String?) async throws -> BulkSettlement { fatalError() }
    func claimBillInvite(token: String, splitId: UUID?) async throws -> ClaimBillInviteResult { fatalError() }
}

private final class CancellationOverviewUseCase: FetchExpenseOverviewUseCaseProtocol {
    func execute() async throws -> ExpenseOverview {
        throw CancellationError()
    }
}

private final class DynamicOverviewUseCase: FetchExpenseOverviewUseCaseProtocol {
    var shouldFail = false
    func execute() async throws -> ExpenseOverview {
        if shouldFail { throw URLError(.badServerResponse) }
        return ExpenseOverview(
            balance: ExpenseBalanceSection(youOwe: 0, owedToYou: 0, netBalance: 0, currency: "VND", topBalances: []),
            needsAttention: ExpenseNeedsAttentionSection(pendingPaymentRequestCount: 0, expensesNeedingConfirmationCount: 0, outstandingSettlementCount: 0, totalActionItems: 0, items: []),
            recentExpenses: [],
            totalSpending: ExpenseTotalSpendingSection(currentPeriodTotal: 0, previousPeriodTotal: 0, percentageChange: 0, currency: "VND")
        )
    }
}

private final class DynamicDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol {
    var shouldFail = false
    func execute(groupId: UUID?) async throws -> [DebtSummary] {
        if shouldFail { throw URLError(.cannotConnectToHost) }
        return [
            DebtSummary(
                user: UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil),
                amount: 10000,
                currency: "VND"
            )
        ]
    }
}

private final class DynamicCounterpartyExpensesUseCase: FetchCounterpartyExpensesUseCaseProtocol {
    var shouldFail = false
    var hasNext = true
    var currentUserId: UUID?

    func execute(counterpartyId: UUID, page: Int, status: CounterpartyExpenseStatus, cursor: String?) async throws -> ExpensePage {
        if shouldFail { throw URLError(.cannotConnectToHost) }
        let friend = UserSummary(id: counterpartyId, username: "cp", displayName: "CP", avatarURL: nil)
        let currentUser = UserSummary(id: currentUserId ?? UUID(), username: "me", displayName: "Me", avatarURL: nil)
        let exp1 = Expense(
            id: UUID(),
            description: "Dinner",
            totalAmount: 50000,
            currency: "VND",
            paidBy: friend,
            splits: [ExpenseSplit(id: UUID(), user: currentUser, amount: 25000, isPaid: false, paymentStatus: .unpaid)]
        )
        let exp2 = Expense(
            id: UUID(),
            description: "Taxi",
            totalAmount: 20000,
            currency: "VND",
            paidBy: currentUser,
            splits: [ExpenseSplit(id: UUID(), user: friend, amount: 20000, isPaid: false, paymentStatus: .unpaid)]
        )
        return ExpensePage(
            expenses: [exp1, exp2],
            page: page,
            totalPages: 2,
            totalItems: 4,
            hasNext: hasNext,
            nextCursor: hasNext ? "cursor_next" : nil
        )
    }
}

private final class DynamicNettingUseCase: FetchNettingSummaryUseCaseProtocol {
    var shouldFail = false
    var direction: NetDirection = .actorOwes
    let currentUserId: UUID
    let friendId: UUID

    init(currentUserId: UUID, friendId: UUID) {
        self.currentUserId = currentUserId
        self.friendId = friendId
    }

    func execute(counterpartyId: UUID) async throws -> NettingSummary {
        if shouldFail { throw URLError(.cannotConnectToHost) }
        return NettingSummary(
            counterparty: UserSummary(id: friendId, username: "friend", displayName: "Friend", avatarURL: nil),
            actorOwesTotal: direction == .actorOwes ? 50000 : 0,
            counterpartyOwesTotal: direction == .counterpartyOwes ? 50000 : 0,
            netAmount: direction == .settled ? 0 : 50000,
            netDirection: direction,
            currency: "VND",
            unpaidSplitCount: 1,
            expensesInvolved: 1,
            pendingSettlement: nil
        )
    }
}

private final class StubListExpensesUseCase: FetchExpensesUseCaseProtocol {
    let expenses: [Expense]
    init(expenses: [Expense]) { self.expenses = expenses }
    func execute(groupId: UUID?, page: Int, cursor: String?) async throws -> [Expense] {
        expenses
    }
}

private final class FailingDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol {
    func execute(groupId: UUID?) async throws -> [DebtSummary] {
        throw URLError(.cannotConnectToHost)
    }
}

private final class FailingCreateExpenseUseCase: CreateExpenseUseCaseProtocol {
    let errorToThrow: Error
    init(error: Error) { self.errorToThrow = error }
    func execute(_ request: CreateExpenseRequest) async throws -> Expense {
        throw errorToThrow
    }
}

private final class FailingOverviewUseCase: FetchExpenseOverviewUseCaseProtocol {
    func execute() async throws -> ExpenseOverview {
        throw URLError(.cannotConnectToHost)
    }
}

private final class FailingAnalyticsUseCase: FetchSpendingAnalyticsUseCaseProtocol {
    func execute(period: SpendingAnalyticsPeriod, months: Int) async throws -> SpendingAnalytics {
        throw URLError(.badServerResponse)
    }
}

private final class FailingGroupsUseCase: FetchGroupExpenseSummaryUseCaseProtocol {
    func execute() async throws -> GroupExpenseSummary {
        throw URLError(.timedOut)
    }
}

private final class FailingExpensesUseCase: FetchExpensesUseCaseProtocol {
    func execute(groupId: UUID?, page: Int, cursor: String?) async throws -> [Expense] {
        throw URLError(.cannotConnectToHost)
    }
}

private final class MockApproveSettlementUseCase: ApproveBulkSettlementUseCaseProtocol {
    var shouldFail = false
    func execute(id: UUID) async throws -> BulkSettlement {
        if shouldFail { throw URLError(.badServerResponse) }
        return BulkSettlement(
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
}

private final class MockRejectSettlementUseCase: RejectBulkSettlementUseCaseProtocol {
    var shouldFail = false
    func execute(id: UUID, reason: String?) async throws -> BulkSettlement {
        if shouldFail { throw URLError(.badServerResponse) }
        return BulkSettlement(
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
}
