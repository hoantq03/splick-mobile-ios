import Common
import DesignSystem
import Foundation
import Localization
import SplickDomain
import SwiftUI

/// Stable navigation value so detail push survives list reload / pull-to-refresh.
public struct ExpenseFriendDetailRoute: Hashable, Sendable {
  public let userId: UUID
  public let username: String
  public let displayName: String
  public let subtitle: String?
  public let avatarURL: URL?
  public let amount: Decimal
  public let currency: String

  public init(debt: DebtSummary) {
    self.userId = debt.user.id
    self.username = debt.user.username
    self.displayName = debt.user.displayName
    self.subtitle = debt.user.subtitle
    self.avatarURL = debt.user.avatarURL
    self.amount = debt.amount
    self.currency = debt.currency
  }

  public var debtSummary: DebtSummary {
    DebtSummary(
      user: UserSummary(
        id: userId,
        username: username,
        displayName: displayName,
        subtitle: subtitle,
        avatarURL: avatarURL
      ),
      amount: amount,
      currency: currency
    )
  }
}

@MainActor
public final class ExpenseFriendListViewModel: ObservableObject {
  @Published private(set) var debts: [DebtSummary] = []
  @Published private(set) var state: LoadingState<[DebtSummary]> = .idle

  private let fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol
  private let languageService: LanguageService

  public init(
    fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol,
    languageService: LanguageService
  ) {
    self.fetchDebtSummaryUseCase = fetchDebtSummaryUseCase
    self.languageService = languageService
  }

  public func load(isPullToRefresh: Bool = false) async {
    // Keep the list mounted during pull-to-refresh so UIRefreshControl is not torn down mid-gesture.
    if !isPullToRefresh {
      state = .loading
    }
    do {
      debts = try await fetchDebtSummaryUseCase.execute(groupId: nil)
        .sorted { abs($0.amount) > abs($1.amount) }
      state = .loaded(debts)
    } catch {
      if isPullToRefresh, !debts.isEmpty {
        state = .loaded(debts)
      } else {
        state = .failed(languageService.localizedMessage(for: error))
      }
    }
  }
}

public struct ExpenseFriendListView: View {
  @ObservedObject private var viewModel: ExpenseFriendListViewModel
  @EnvironmentObject private var languageService: LanguageService
  private let onSelectFriend: (DebtSummary) -> Void

  public init(
    viewModel: ExpenseFriendListViewModel,
    onSelectFriend: @escaping (DebtSummary) -> Void
  ) {
    self.viewModel = viewModel
    self.onSelectFriend = onSelectFriend
  }

  public var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        LoadingView(message: languageService.text(.expenseFriendsLoading))
      case .loaded where viewModel.debts.isEmpty:
        EmptyStateView(
          icon: "person.2",
          title: languageService.text(.expenseFriendsEmptyTitle),
          message: languageService.text(.expenseFriendsEmptyMessage)
        )
      case .loaded:
        friendRecords
      case .failed(let message):
        ErrorView(message: message) {
          Task { await viewModel.load() }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task {
      if case .idle = viewModel.state {
        await viewModel.load()
      }
    }
  }

  private var friendRecords: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.debts, id: \.user.id) { debt in
          Button {
            onSelectFriend(debt)
          } label: {
            friendRow(debt)
          }
          .buttonStyle(ExpenseFriendRowButtonStyle())

          if debt.user.id != viewModel.debts.last?.user.id {
            Divider()
              .padding(.leading, 64)
          }
        }
      }
      .padding(.horizontal, SplickTheme.Spacing.md)
    }
    .splickInstantScrollTaps()
    .refreshable { await viewModel.load(isPullToRefresh: true) }
  }

  private func friendRow(_ debt: DebtSummary) -> some View {
    HStack(spacing: SplickTheme.Spacing.sm) {
      AvatarView(
        imageURL: debt.user.avatarURL,
        name: debt.user.displayName,
        size: .medium,
        userId: debt.user.id
      )
      .allowsHitTesting(false)

      VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
        Text(debt.user.displayName)
          .font(SplickTheme.Typography.headline)
          .foregroundStyle(SplickTheme.Colors.textPrimary)
        Text(balanceLabel(debt))
          .font(SplickTheme.Typography.caption)
          .foregroundStyle(balanceColor(debt))
      }

      Spacer(minLength: 0)

      Text(signedAmount(debt))
        .font(SplickTheme.Typography.headline.monospacedDigit())
        .foregroundStyle(balanceColor(debt))

      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(SplickTheme.Colors.textTertiary)
    }
    .padding(.vertical, SplickTheme.Spacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("\(debt.user.displayName), \(balanceLabel(debt)), \(signedAmount(debt))")
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

  private func signedAmount(_ debt: DebtSummary) -> String {
    let prefix = debt.amount > 0 ? "+" : debt.amount < 0 ? "−" : ""
    return prefix + abs(debt.amount).chartAmountString(currencyCode: debt.currency)
  }
}

private struct ExpenseFriendRowButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.72 : 1)
      .contentShape(Rectangle())
  }
}
