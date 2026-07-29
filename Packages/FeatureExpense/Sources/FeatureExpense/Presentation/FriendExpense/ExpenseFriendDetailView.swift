import Common
import DesignSystem
import Foundation
import Localization
import SplickDomain
import SwiftUI

public typealias ExpenseEvidenceUpload = @Sendable (Data, String) async throws -> URL

@MainActor
public final class ExpenseFriendDetailViewModel: ObservableObject {
  @Published private(set) var summary: NettingSummary?
  @Published private(set) var expenses: [Expense] = []
  @Published private(set) var state: LoadingState<[Expense]> = .idle
  @Published private(set) var isLoadingMore = false
  @Published private(set) var hasNextPage = false
  @Published private(set) var loadMoreError: String?
  @Published private(set) var bulkSettlement: BulkSettlement?

  let counterparty: UserSummary
  let currentUserId: UUID?

  private let fetchExpensesUseCase: FetchCounterpartyExpensesUseCaseProtocol
  private let fetchNettingUseCase: FetchNettingSummaryUseCaseProtocol
  private let submitUseCase: SubmitBulkSettlementUseCaseProtocol
  private let approveUseCase: ApproveBulkSettlementUseCaseProtocol
  private let rejectUseCase: RejectBulkSettlementUseCaseProtocol
  private let uploadEvidence: ExpenseEvidenceUpload
  private let languageService: LanguageService
  private var currentPage = 0

  public init(
    counterparty: UserSummary,
    currentUserId: UUID?,
    fetchExpensesUseCase: FetchCounterpartyExpensesUseCaseProtocol,
    fetchNettingUseCase: FetchNettingSummaryUseCaseProtocol,
    submitUseCase: SubmitBulkSettlementUseCaseProtocol,
    approveUseCase: ApproveBulkSettlementUseCaseProtocol,
    rejectUseCase: RejectBulkSettlementUseCaseProtocol,
    uploadEvidence: @escaping ExpenseEvidenceUpload,
    languageService: LanguageService
  ) {
    self.counterparty = counterparty
    self.currentUserId = currentUserId
    self.fetchExpensesUseCase = fetchExpensesUseCase
    self.fetchNettingUseCase = fetchNettingUseCase
    self.submitUseCase = submitUseCase
    self.approveUseCase = approveUseCase
    self.rejectUseCase = rejectUseCase
    self.uploadEvidence = uploadEvidence
    self.languageService = languageService
  }

  var youOweExpenses: [Expense] {
    expenses.filter {
      let state = $0.userDebtState(userId: currentUserId)
      return state == .oweUnpaid || state == .owePaid
    }
  }

  var theyOweExpenses: [Expense] {
    expenses.filter {
      let state = $0.userDebtState(userId: currentUserId)
      return state == .owedUnpaid || state == .owedPaid
    }
  }

  var canQuickSettle: Bool {
    guard let summary, let currentUserId else { return false }
    return currentUserId == expectedNetDebtorUserId
      && summary.netAmount > 0
      && bulkSettlement?.status != .pending
  }

  var canReviewPendingSettlement: Bool {
    guard let settlement = bulkSettlement, let currentUserId else { return false }
    return settlement.status == .pending && settlement.creditorUserId == currentUserId
  }

  var isPendingSettlementDebtor: Bool {
    guard let settlement = bulkSettlement, let currentUserId else { return false }
    return settlement.status == .pending && settlement.debtorUserId == currentUserId
  }

  private var expectedNetDebtorUserId: UUID? {
    guard let summary else { return nil }
    switch summary.netDirection {
    case .actorOwes:
      return currentUserId
    case .counterpartyOwes:
      return counterparty.id
    case .settled:
      return nil
    }
  }

  public func load(isPullToRefresh: Bool = false) async {
    // Keep content mounted during pull-to-refresh so the refresh control stays attached.
    if !isPullToRefresh {
      state = .loading
    }
    loadMoreError = nil
    currentPage = 0
    do {
      async let summaryTask = fetchNettingUseCase.execute(counterpartyId: counterparty.id)
      async let pageTask = fetchExpensesUseCase.execute(
        counterpartyId: counterparty.id,
        page: 0,
        status: .all
      )
      let (newSummary, page) = try await (summaryTask, pageTask)
      summary = newSummary
      bulkSettlement = newSummary.pendingSettlement
      expenses = page.expenses
      hasNextPage = page.hasNext
      state = .loaded(expenses)
    } catch {
      if isPullToRefresh, !expenses.isEmpty {
        state = .loaded(expenses)
      } else {
        state = .failed(languageService.localizedMessage(for: error))
      }
    }
  }

  public func refresh() async {
    await load(isPullToRefresh: true)
  }

  public func loadMore() async {
    guard hasNextPage, !isLoadingMore else { return }
    isLoadingMore = true
    loadMoreError = nil
    defer { isLoadingMore = false }
    do {
      let nextPage = currentPage + 1
      let page = try await fetchExpensesUseCase.execute(
        counterpartyId: counterparty.id,
        page: nextPage,
        status: .all
      )
      currentPage = nextPage
      let existingIDs = Set(expenses.map(\.id))
      expenses.append(contentsOf: page.expenses.filter { !existingIDs.contains($0.id) })
      hasNextPage = page.hasNext
      state = .loaded(expenses)
    } catch {
      loadMoreError = languageService.localizedMessage(for: error)
    }
  }

  public func didSubmit(_ settlement: BulkSettlement) {
    bulkSettlement = settlement
  }

  public func approveSettlement() async {
    guard canReviewPendingSettlement, let settlement = bulkSettlement else { return }
    do {
      bulkSettlement = try await approveUseCase.execute(id: settlement.id)
      await refresh()
    } catch {
      state = .failed(languageService.localizedMessage(for: error))
    }
  }

  public func rejectSettlement(reason: String?) async {
    guard canReviewPendingSettlement, let settlement = bulkSettlement else { return }
    do {
      bulkSettlement = try await rejectUseCase.execute(id: settlement.id, reason: reason)
      await refresh()
    } catch {
      state = .failed(languageService.localizedMessage(for: error))
    }
  }

  func makeBulkSettleViewModel() -> BulkSettleViewModel {
    BulkSettleViewModel(
      counterpartyId: counterparty.id,
      uploadEvidence: uploadEvidence,
      submitUseCase: submitUseCase,
      languageService: languageService
    )
  }
}

public struct ExpenseFriendDetailView: View {
  @StateObject private var viewModel: ExpenseFriendDetailViewModel
  @EnvironmentObject private var languageService: LanguageService
  @Environment(\.openLinkedPost) private var openLinkedPost
  @State private var showBulkSettlement = false
  @State private var showRejectPrompt = false
  @State private var rejectionReason = ""

  public init(viewModel: ExpenseFriendDetailViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  public var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        LoadingView(message: languageService.text(.expenseLoading))
      case .failed(let message):
        ErrorView(message: message) {
          Task { await viewModel.load() }
        }
      case .loaded:
        content
      }
    }
    .navigationTitle(viewModel.counterparty.displayName)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if case .idle = viewModel.state {
        await viewModel.load()
      }
    }
    .sheet(isPresented: $showBulkSettlement) {
      BulkSettleView(viewModel: viewModel.makeBulkSettleViewModel()) { settlement in
        viewModel.didSubmit(settlement)
        showBulkSettlement = false
      }
      .presentationDetents([.medium, .large])
    }
    .alert(languageService.text(.expenseBulkReject), isPresented: $showRejectPrompt) {
      TextField(languageService.text(.expenseBulkRejectReason), text: $rejectionReason)
      Button(languageService.text(.commonCancel), role: .cancel) {}
      Button(languageService.text(.expenseBulkReject), role: .destructive) {
        let reason = rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await viewModel.rejectSettlement(reason: reason.isEmpty ? nil : reason) }
      }
    }
  }

  private var content: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
        if let summary = viewModel.summary {
          summaryCard(summary)
        }
        expenseSection(
          title: languageService.text(.expenseYouOwe),
          expenses: viewModel.youOweExpenses
        )
        expenseSection(
          title: languageService.text(.expenseYouAreOwed),
          expenses: viewModel.theyOweExpenses
        )
        if viewModel.hasNextPage {
          SplickButton(
            viewModel.isLoadingMore
              ? languageService.text(.expenseLoading)
              : languageService.text(.expenseFriendLoadMore),
            style: .secondary
          ) {
            Task { await viewModel.loadMore() }
          }
          .disabled(viewModel.isLoadingMore)
        }
        if let loadMoreError = viewModel.loadMoreError {
          Text(loadMoreError)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.error)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(SplickTheme.Spacing.md)
    }
    .refreshable { await viewModel.refresh() }
  }

  private func summaryCard(_ summary: NettingSummary) -> some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
      Text(languageService.text(.expenseFriendSummary))
        .font(SplickTheme.Typography.headline)
      HStack {
        metric(
          languageService.text(.expenseFriendYouOwe),
          summary.actorOwesTotal.chartAmountString(currencyCode: summary.currency)
        )
        metric(
          languageService.text(.expenseFriendOwesYou),
          summary.counterpartyOwesTotal.chartAmountString(currencyCode: summary.currency)
        )
      }
      Divider()
      HStack {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
          Text(languageService.text(.expenseFriendNetAmount))
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
          Text(summary.netAmount.chartAmountString(currencyCode: summary.currency))
            .font(SplickTheme.Typography.title.monospacedDigit())
        }
        Spacer()
        VStack(alignment: .trailing, spacing: SplickTheme.Spacing.xxxs) {
          Text(languageService.format(.expenseFriendExpenseCount, summary.expensesInvolved))
          Text(languageService.format(.expenseFriendSplitCount, summary.unpaidSplitCount))
        }
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      }
      settlementAction(summary)
    }
    .splickCard()
    .accessibilityElement(children: .contain)
  }

  private func metric(_ title: String, _ amount: String) -> some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
      Text(title)
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      Text(amount)
        .font(SplickTheme.Typography.headline.monospacedDigit())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func settlementAction(_ summary: NettingSummary) -> some View {
    if viewModel.bulkSettlement?.status == .pending {
      if viewModel.canReviewPendingSettlement {
        VStack(spacing: SplickTheme.Spacing.xs) {
          Label(languageService.text(.expenseBulkPending), systemImage: "clock.fill")
            .foregroundStyle(SplickTheme.Colors.warning)
          HStack {
            SplickButton(languageService.text(.expenseBulkReject), style: .destructive) {
              showRejectPrompt = true
            }
            SplickButton(languageService.text(.expenseBulkApprove), style: .primary) {
              Task { await viewModel.approveSettlement() }
            }
          }
        }
      } else if viewModel.isPendingSettlementDebtor {
        Label(languageService.text(.expenseBulkPending), systemImage: "clock.fill")
          .foregroundStyle(SplickTheme.Colors.warning)
      } else {
        Label(languageService.text(.expenseFriendWaiting), systemImage: "clock")
          .foregroundStyle(SplickTheme.Colors.textSecondary)
      }
    } else if viewModel.canQuickSettle {
      SplickButton(languageService.text(.expenseFriendQuickSettle), style: .primary) {
        showBulkSettlement = true
      }
      .accessibilityHint(languageService.text(.expenseBulkEvidence))
    } else {
      Label(
        summary.netDirection == .settled
          ? languageService.text(.expenseFriendSettled)
          : languageService.text(.expenseFriendWaiting),
        systemImage: summary.netDirection == .settled ? "checkmark.circle.fill" : "clock"
      )
      .foregroundStyle(
        summary.netDirection == .settled
          ? SplickTheme.Colors.success
          : SplickTheme.Colors.textSecondary
      )
    }
  }

  @ViewBuilder
  private func expenseSection(title: String, expenses: [Expense]) -> some View {
    if !expenses.isEmpty {
      VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
        Text(title)
          .font(SplickTheme.Typography.headline)

        VStack(spacing: 0) {
          ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
            ExpenseRowView(
              expense: expense,
              currentUserId: viewModel.currentUserId,
              layout: .grouped,
              onCreatorTap: {},
              onTap: { openLinkedPost(for: expense) }
            )

            if index < expenses.count - 1 {
              Divider()
                .padding(.leading, 84)
            }
          }
        }
        .background {
          RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
            .fill(SplickTheme.Colors.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
      }
    }
  }

  private func openLinkedPost(for expense: Expense) {
    guard let postId = expense.postId else { return }
    openLinkedPost?(postId, true)
  }
}
