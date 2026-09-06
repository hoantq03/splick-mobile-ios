import Common
import DesignSystem
import Foundation
import Localization
import SplickDomain
import SwiftUI

@MainActor
public final class ExpenseGroupDetailViewModel: ObservableObject {
  @Published private(set) var members: [DebtSummary] = []
  @Published private(set) var state: LoadingState<[DebtSummary]> = .idle

  let group: GroupExpenseItem
  private let currentUserId: UUID?
  private let fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol
  private let languageService: LanguageService

  public init(
    group: GroupExpenseItem,
    currentUserId: UUID?,
    fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol,
    languageService: LanguageService
  ) {
    self.group = group
    self.currentUserId = currentUserId
    self.fetchDebtSummaryUseCase = fetchDebtSummaryUseCase
    self.languageService = languageService
  }

  func load(isPullToRefresh: Bool = false) async {
    if !isPullToRefresh, members.isEmpty {
      state = .loading
    }
    do {
      let debts = try await fetchDebtSummaryUseCase.execute(groupId: group.groupId)
      members = Self.mergeMembers(
        debts: debts,
        avatars: group.memberAvatars,
        currentUserId: currentUserId,
        currency: group.currency
      )
      state = .loaded(members)
    } catch is CancellationError {
      return
    } catch {
      if isPullToRefresh, !members.isEmpty {
        state = .loaded(members)
      } else {
        state = .failed(languageService.localizedMessage(for: error))
      }
    }
  }

  static func mergeMembers(
    debts: [DebtSummary],
    avatars: [UserSummary],
    currentUserId: UUID?,
    currency: String
  ) -> [DebtSummary] {
    var byId: [UUID: DebtSummary] = [:]
    for debt in debts where debt.user.id != currentUserId {
      byId[debt.user.id] = debt
    }
    for member in avatars where member.id != currentUserId {
      if byId[member.id] == nil {
        byId[member.id] = DebtSummary(user: member, amount: 0, currency: currency)
      }
    }
    return byId.values.sorted { abs($0.amount) > abs($1.amount) }
  }
}

struct ExpenseGroupDetailView: View {
  @StateObject private var viewModel: ExpenseGroupDetailViewModel
  @EnvironmentObject private var languageService: LanguageService
  var onSelectMember: (DebtSummary) -> Void

  init(
    viewModel: ExpenseGroupDetailViewModel,
    onSelectMember: @escaping (DebtSummary) -> Void
  ) {
    _viewModel = StateObject(wrappedValue: viewModel)
    self.onSelectMember = onSelectMember
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
        overviewHeader
        membersSection
      }
      .padding(.horizontal, SplickTheme.Spacing.md)
      .padding(.top, SplickTheme.Spacing.md)
      .padding(.bottom, SplickTabBarMetrics.floatingClearance + SplickTheme.Spacing.md)
    }
    .background(SplickTheme.Colors.background.ignoresSafeArea())
    .navigationTitle(viewModel.group.groupName)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if case .idle = viewModel.state {
        await viewModel.load()
      }
    }
    .refreshable {
      await viewModel.load(isPullToRefresh: true)
    }
  }

  private var overviewHeader: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      HStack(spacing: SplickTheme.Spacing.sm) {
        AvatarView(
          imageURL: viewModel.group.groupAvatarURL,
          name: viewModel.group.groupName,
          size: .medium
        )
        Text(viewModel.group.groupName)
          .font(SplickTheme.Typography.headline)
        Spacer()
      }
      HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
        overviewMetric(
          languageService.text(.expenseOverviewGroupTotal),
          viewModel.group.totalGroupSpending,
          signPrefix: "-"
        )
        overviewMetric(
          languageService.text(.expenseOverviewGroupPaid),
          viewModel.group.userPaidTotal,
          signPrefix: "-"
        )
        overviewMetric(
          languageService.text(overviewNetBalanceTitleKey(viewModel.group.userBalance)),
          viewModel.group.userBalance,
          signPrefix: ""
        )
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private var membersSection: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
      Text(languageService.text(.expenseGroupDetailMembers))
        .font(SplickTheme.Typography.headline)
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
          .frame(maxWidth: .infinity, minHeight: 80)
      case .failed(let message):
        ErrorView(message: message) {
          Task { await viewModel.load() }
        }
      case .loaded where viewModel.members.isEmpty:
        Text(languageService.text(.expenseGroupDetailEmpty))
          .font(SplickTheme.Typography.body)
          .foregroundStyle(SplickTheme.Colors.textSecondary)
      case .loaded:
        VStack(spacing: 0) {
          ForEach(Array(viewModel.members.enumerated()), id: \.element.user.id) { index, debt in
            Button {
              onSelectMember(debt)
            } label: {
              memberRow(debt)
            }
            .buttonStyle(.plain)
            if index < viewModel.members.count - 1 {
              Rectangle()
                .fill(SplickTheme.Colors.divider.opacity(0.45))
                .frame(height: 0.5)
                .padding(.leading, 56)
            }
          }
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private func overviewMetric(_ title: String, _ amount: Decimal, signPrefix: String?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      Text(signedGroupAmount(amount, prefix: signPrefix))
        .font(SplickTheme.Typography.caption)
        .fontWeight(.semibold)
        .foregroundStyle(metricColor(amount, forcedMinus: signPrefix == "-"))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func memberRow(_ debt: DebtSummary) -> some View {
    HStack(spacing: SplickTheme.Spacing.sm) {
      AvatarView(
        imageURL: debt.user.avatarURL,
        name: debt.user.displayName,
        size: .medium,
        userId: debt.user.id
      )
      VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
        Text(debt.user.displayName)
          .font(SplickTheme.Typography.headline)
          .foregroundStyle(SplickTheme.Colors.textPrimary)
        Text(balanceLabel(debt))
          .font(SplickTheme.Typography.caption)
          .foregroundStyle(balanceColor(debt))
      }
      Spacer(minLength: 0)
      Text(signedMemberAmount(debt))
        .font(SplickTheme.Typography.headline.monospacedDigit())
        .foregroundStyle(balanceColor(debt))
      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(SplickTheme.Colors.textTertiary)
    }
    .padding(.vertical, SplickTheme.Spacing.sm)
    .contentShape(Rectangle())
  }

  private func balanceLabel(_ debt: DebtSummary) -> String {
    if debt.amount > 0 { return languageService.text(.expenseFriendOwesYou) }
    if debt.amount < 0 { return languageService.text(.expenseFriendYouOwe) }
    return languageService.text(.expenseFriendSettled)
  }

  private func balanceColor(_ debt: DebtSummary) -> Color {
    if debt.amount > 0 { return SplickTheme.Colors.success }
    if debt.amount < 0 { return SplickTheme.Colors.error }
    return SplickTheme.Colors.textSecondary
  }

  private func signedMemberAmount(_ debt: DebtSummary) -> String {
    let prefix = debt.amount > 0 ? "+" : debt.amount < 0 ? "−" : ""
    return prefix + formattedAmount(abs(debt.amount), currency: debt.currency)
  }

  private func signedGroupAmount(_ amount: Decimal, prefix: String?) -> String {
    let body = formattedAmount(abs(amount), currency: viewModel.group.currency)
    if amount == 0 { return body }
    if let prefix {
      return prefix.isEmpty ? body : prefix + body
    }
    return (amount > 0 ? "+" : "−") + body
  }

  private func formattedAmount(_ amount: Decimal, currency: String) -> String {
    let symbol = Decimal.displayCurrencySymbol(for: currency)
    return "\(SplickMoneyFormat.string(from: amount))\(symbol)"
  }

  private func metricColor(_ amount: Decimal, forcedMinus: Bool) -> Color {
    if forcedMinus { return SplickTheme.Colors.error }
    if amount > 0 { return SplickTheme.Colors.success }
    if amount < 0 { return SplickTheme.Colors.error }
    return SplickTheme.Colors.textPrimary
  }
}
