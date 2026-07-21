import Foundation
import Localization
import SplickDomain
import Storage
import XCTest

@testable import FeatureExpense

@MainActor
final class ExpenseFriendViewModelTests: XCTestCase {
  private let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  func test_netDirection_onlyActorOwesEnablesQuickSettlement() async {
    let actorOwes = makeSummary(direction: .actorOwes, amount: 100)
    let viewModel = makeDetailViewModel(summary: actorOwes)

    await viewModel.load()

    XCTAssertTrue(viewModel.canQuickSettle)
    XCTAssertEqual(viewModel.summary?.netDirection, .actorOwes)

    let waitingViewModel = makeDetailViewModel(
      summary: makeSummary(direction: .counterpartyOwes, amount: 100)
    )
    await waitingViewModel.load()
    XCTAssertFalse(waitingViewModel.canQuickSettle)
  }

  func test_loadFailure_exposesFailedState() async {
    let viewModel = makeDetailViewModel(summaryError: TestError.failed)

    await viewModel.load()

    guard case .failed = viewModel.state else {
      return XCTFail("Expected failed state")
    }
  }

  func test_submitSuccess_uploadsThenReturnsPendingSettlement() async {
    let settlement = makeSettlement(status: .pending)
    let viewModel = BulkSettleViewModel(
      counterpartyId: counterparty.id,
      uploadEvidence: { _, _ in URL(string: "https://example.com/uploaded.jpg")! },
      submitUseCase: StubSubmitUseCase(result: .success(settlement)),
      languageService: makeLanguageService()
    )
    viewModel.selectEvidence(data: Data([1, 2, 3]))

    await viewModel.submit()

    XCTAssertEqual(viewModel.state, .success)
    XCTAssertEqual(viewModel.settlement, settlement)
  }

  func test_submitFailure_exposesFailedState() async {
    let viewModel = BulkSettleViewModel(
      counterpartyId: counterparty.id,
      uploadEvidence: { _, _ in throw TestError.failed },
      submitUseCase: StubSubmitUseCase(result: .failure(TestError.failed)),
      languageService: makeLanguageService()
    )
    viewModel.selectEvidence(data: Data([1]))

    await viewModel.submit()

    guard case .failed = viewModel.state else {
      return XCTFail("Expected failed state")
    }
  }

  func test_approvalRefreshesSummaryAndRecords() async {
    let pending = makeSettlement(
      status: .pending,
      debtorUserId: counterparty.id,
      creditorUserId: currentUserId
    )
    let netting = StubNettingUseCase(results: [
      .success(makeSummary(direction: .counterpartyOwes, amount: 100, pending: pending)),
      .success(makeSummary(direction: .settled, amount: 0)),
    ])
    let expenses = StubExpensesUseCase(result: .success(emptyPage))
    let approved = makeSettlement(
      status: .approved,
      id: pending.id,
      debtorUserId: pending.debtorUserId,
      creditorUserId: pending.creditorUserId
    )
    let viewModel = makeDetailViewModel(
      netting: netting,
      expenses: expenses,
      approve: StubApproveUseCase(result: .success(approved))
    )
    await viewModel.load()

    await viewModel.approveSettlement()

    let nettingCallCount = await netting.callCount
    let expenseCallCount = await expenses.callCount
    XCTAssertNil(viewModel.bulkSettlement)
    XCTAssertEqual(nettingCallCount, 2)
    XCTAssertEqual(expenseCallCount, 2)
  }

  func test_load_restoresPendingSettlementAndCreditorActions() async {
    let pending = makeSettlement(
      status: .pending,
      debtorUserId: counterparty.id,
      creditorUserId: currentUserId
    )
    let viewModel = makeDetailViewModel(
      summary: makeSummary(direction: .counterpartyOwes, amount: 100, pending: pending)
    )

    await viewModel.load()

    XCTAssertEqual(viewModel.bulkSettlement, pending)
    XCTAssertTrue(viewModel.canReviewPendingSettlement)
    XCTAssertFalse(viewModel.isPendingSettlementDebtor)
    XCTAssertFalse(viewModel.canQuickSettle)
  }

  func test_load_restoresPendingSettlementForDebtorWithoutReviewActions() async {
    let pending = makeSettlement(
      status: .pending,
      debtorUserId: currentUserId,
      creditorUserId: counterparty.id
    )
    let viewModel = makeDetailViewModel(
      summary: makeSummary(direction: .actorOwes, amount: 100, pending: pending)
    )

    await viewModel.load()

    XCTAssertTrue(viewModel.isPendingSettlementDebtor)
    XCTAssertFalse(viewModel.canReviewPendingSettlement)
    XCTAssertFalse(viewModel.canQuickSettle)
  }

  func test_canonicalPageEnvelopeDecoding() throws {
    let data = Data(
      """
      {
        "content": [{"id": 7}],
        "page": 1,
        "limit": 20,
        "totalElements": 9223372036854775807,
        "totalPages": 3
      }
      """.utf8
    )

    let page = try JSONDecoder().decode(ExpensePageResponseDTO<TestPageItemDTO>.self, from: data)

    XCTAssertEqual(page.content.map(\.id), [7])
    XCTAssertEqual(page.page, 1)
    XCTAssertEqual(page.limit, 20)
    XCTAssertEqual(page.totalElements, Int64.max)
    XCTAssertEqual(page.totalPages, 3)
    XCTAssertEqual(page.clampedTotalElements, Int.max)
    XCTAssertTrue(page.hasNext)
  }

  func test_canonicalNettingDecoding_mapsPendingSettlement() throws {
    let pendingId = UUID()
    let data = Data(
      """
      {
        "counterparty": {
          "id": "\(counterparty.id.uuidString)",
          "username": "friend",
          "displayName": "Friend",
          "avatarUrl": null
        },
        "actorOwesTotal": "0",
        "counterpartyOwesTotal": "100",
        "netAmount": "100",
        "netDirection": "COUNTERPARTY_OWES",
        "currency": "VND",
        "unpaidSplitCount": 2,
        "expensesInvolved": 1,
        "pendingSettlement": {
          "id": "\(pendingId.uuidString)",
          "debtorUserId": "\(counterparty.id.uuidString)",
          "creditorUserId": "\(currentUserId.uuidString)",
          "amount": "100",
          "currency": "VND",
          "evidenceUrl": "https://example.com/evidence.jpg",
          "note": null,
          "status": "PENDING_APPROVAL",
          "splitCount": 2,
          "createdAt": "2026-07-21T12:00:00Z",
          "reviewedAt": null,
          "rejectReason": null
        }
      }
      """.utf8
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let dto = try decoder.decode(NettingSummaryDTO.self, from: data)
    let summary = try ExpenseMapper.toNettingSummary(dto)

    XCTAssertEqual(summary.pendingSettlement?.id, pendingId)
    XCTAssertEqual(summary.pendingSettlement?.status, .pending)
    XCTAssertEqual(summary.pendingSettlement?.creditorUserId, currentUserId)
    XCTAssertEqual(summary.pendingSettlement?.splitCount, 2)
  }

  private func makeDetailViewModel(
    summary: NettingSummary? = nil,
    summaryError: Error? = nil,
    netting: StubNettingUseCase? = nil,
    expenses: StubExpensesUseCase? = nil,
    approve: StubApproveUseCase? = nil
  ) -> ExpenseFriendDetailViewModel {
    let summaryResult: Result<NettingSummary, Error>
    if let summaryError {
      summaryResult = .failure(summaryError)
    } else {
      summaryResult = .success(summary ?? makeSummary(direction: .settled, amount: 0))
    }
    return ExpenseFriendDetailViewModel(
      counterparty: counterparty,
      currentUserId: currentUserId,
      fetchExpensesUseCase: expenses ?? StubExpensesUseCase(result: .success(emptyPage)),
      fetchNettingUseCase: netting ?? StubNettingUseCase(result: summaryResult),
      submitUseCase: StubSubmitUseCase(result: .success(makeSettlement(status: .pending))),
      approveUseCase: approve
        ?? StubApproveUseCase(
          result: .success(makeSettlement(status: .approved))
        ),
      rejectUseCase: StubRejectUseCase(),
      uploadEvidence: { _, _ in URL(string: "https://example.com/uploaded.jpg")! },
      languageService: makeLanguageService()
    )
  }

  private func makeLanguageService() -> LanguageService {
    let suite = "ExpenseFriendViewModelTests.\(UUID().uuidString)"
    return LanguageService(
      userDefaults: UserDefaultsService(defaults: UserDefaults(suiteName: suite)!)
    )
  }

  private var counterparty: UserSummary {
    UserSummary(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      username: "friend",
      displayName: "Friend",
      avatarURL: nil
    )
  }

  private var emptyPage: ExpensePage {
    ExpensePage(expenses: [], page: 0, totalPages: 1, totalItems: 0, hasNext: false)
  }

  private func makeSummary(
    direction: NetDirection,
    amount: Decimal,
    pending: BulkSettlement? = nil
  ) -> NettingSummary {
    NettingSummary(
      counterparty: counterparty,
      actorOwesTotal: direction == .actorOwes ? amount : 0,
      counterpartyOwesTotal: direction == .counterpartyOwes ? amount : 0,
      netAmount: amount,
      netDirection: direction,
      currency: "VND",
      unpaidSplitCount: amount > 0 ? 1 : 0,
      expensesInvolved: amount > 0 ? 1 : 0,
      pendingSettlement: pending
    )
  }

  private func makeSettlement(
    status: BulkSettlementStatus,
    id: UUID = UUID(),
    debtorUserId: UUID? = nil,
    creditorUserId: UUID? = nil
  ) -> BulkSettlement {
    BulkSettlement(
      id: id,
      debtorUserId: debtorUserId ?? currentUserId,
      creditorUserId: creditorUserId ?? counterparty.id,
      amount: 100,
      currency: "VND",
      evidenceURL: URL(string: "https://example.com/evidence.jpg")!,
      status: status,
      splitCount: 1,
      createdAt: .now
    )
  }
}

private actor StubNettingUseCase: FetchNettingSummaryUseCaseProtocol {
  private let results: [Result<NettingSummary, Error>]
  private(set) var callCount = 0

  init(result: Result<NettingSummary, Error>) {
    self.results = [result]
  }

  init(results: [Result<NettingSummary, Error>]) {
    self.results = results
  }

  func execute(counterpartyId: UUID) async throws -> NettingSummary {
    let result = results[min(callCount, results.count - 1)]
    callCount += 1
    return try result.get()
  }
}

private actor StubExpensesUseCase: FetchCounterpartyExpensesUseCaseProtocol {
  private let result: Result<ExpensePage, Error>
  private(set) var callCount = 0

  init(result: Result<ExpensePage, Error>) {
    self.result = result
  }

  func execute(
    counterpartyId: UUID,
    page: Int,
    status: CounterpartyExpenseStatus
  ) async throws -> ExpensePage {
    callCount += 1
    return try result.get()
  }
}

private struct StubSubmitUseCase: SubmitBulkSettlementUseCaseProtocol {
  let result: Result<BulkSettlement, Error>

  func execute(
    counterpartyId: UUID,
    evidenceURL: URL,
    note: String?
  ) async throws -> BulkSettlement {
    try result.get()
  }
}

private struct StubApproveUseCase: ApproveBulkSettlementUseCaseProtocol {
  let result: Result<BulkSettlement, Error>

  func execute(id: UUID) async throws -> BulkSettlement {
    try result.get()
  }
}

private struct StubRejectUseCase: RejectBulkSettlementUseCaseProtocol {
  func execute(id: UUID, reason: String?) async throws -> BulkSettlement {
    throw TestError.failed
  }
}

private enum TestError: Error {
  case failed
}

private struct TestPageItemDTO: Decodable {
  let id: Int
}
