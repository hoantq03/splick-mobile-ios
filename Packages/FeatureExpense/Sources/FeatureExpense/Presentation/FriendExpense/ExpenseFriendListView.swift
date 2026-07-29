import Common
import DesignSystem
import Foundation
import Localization
import SplickDomain
import SwiftUI

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
  private let makeDetailViewModel: (DebtSummary) -> ExpenseFriendDetailViewModel

  public init(
    viewModel: ExpenseFriendListViewModel,
    makeDetailViewModel: @escaping (DebtSummary) -> ExpenseFriendDetailViewModel
  ) {
    self.viewModel = viewModel
    self.makeDetailViewModel = makeDetailViewModel
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
        List(viewModel.debts, id: \.user.id) { debt in
          NavigationLink {
            ExpenseFriendDetailView(viewModel: makeDetailViewModel(debt))
          } label: {
            friendRow(debt)
          }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.load(isPullToRefresh: true) }
      case .failed(let message):
        ErrorView(message: message) {
          Task { await viewModel.load() }
        }
      }
    }
    .task {
      if case .idle = viewModel.state {
        await viewModel.load()
      }
    }
  }

  private func friendRow(_ debt: DebtSummary) -> some View {
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
      Spacer()
      Text(signedAmount(debt))
        .font(SplickTheme.Typography.headline.monospacedDigit())
        .foregroundStyle(balanceColor(debt))
    }
    .padding(.vertical, SplickTheme.Spacing.xxs)
    .accessibilityElement(children: .combine)
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
