import SwiftUI
import Charts
import DesignSystem
import Common
import Localization
import SplickDomain

struct ExpenseOverviewTab: View {
  @ObservedObject var viewModel: ExpenseOverviewViewModel
  @ObservedObject var refreshController: SplickRefreshController
  @EnvironmentObject private var languageService: LanguageService
  @Environment(\.pullToRefreshActive) private var pullToRefreshActive
  let overviewScrollTopSignal: Int

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        LoadingView(message: languageService.text(.expenseLoading))
          .splickSegmentPagerPageTopInset(isEnabled: true)
      case .failed(let message):
        ErrorView(message: message) {
          Task { await viewModel.load() }
        }
        .splickSegmentPagerPageTopInset(isEnabled: true)
      default:
        overviewContent
      }
    }
  }

  private var overviewContent: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: SplickTheme.Spacing.md) {
          Color.clear.frame(height: 0).id("expenseOverviewScrollTop")
          if let overview = viewModel.overview {
            ExpenseBalanceSectionView(section: overview.balance)
            ExpenseNeedsAttentionSectionView(section: overview.needsAttention)
            ExpenseRecentExpensesSectionView(items: overview.recentExpenses)
            ExpenseTotalSpendingSectionView(section: overview.totalSpending)
          }
          ExpenseSpendingChartsSectionView(
            analytics: viewModel.analytics,
            state: viewModel.analyticsState
          )
          ExpenseGroupsSectionView(groups: viewModel.groups, state: viewModel.groupsState)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTabBarMetrics.floatingClearance + SplickTheme.Spacing.md)
        .transaction { transaction in
          if pullToRefreshActive {
            transaction.animation = nil
          }
        }
      }
      .scrollChromeTracking()
      .splickSegmentPagerScrollInsets()
      .splickScrollSoftTopEdge()
      .splickNativeRefreshable(controller: refreshController) {
        await viewModel.load(isPullToRefresh: true)
      }
      .onChange(of: overviewScrollTopSignal) { _ in
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
          proxy.scrollTo("expenseOverviewScrollTop", anchor: .top)
        }
      }
    }
  }
}

struct ExpenseBalanceSectionView: View {
  let section: ExpenseBalanceSection
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      Text(languageService.text(.expenseOverviewBalanceTitle))
        .font(SplickTheme.Typography.headline)
        .foregroundStyle(SplickTheme.Colors.textPrimary)
      HStack(spacing: SplickTheme.Spacing.sm) {
        metric(
          title: languageService.text(.expenseYouOwe),
          amount: section.youOwe,
          color: SplickTheme.Colors.error
        )
        metric(
          title: languageService.text(.expenseYouAreOwed),
          amount: section.owedToYou,
          color: SplickTheme.Colors.success
        )
      }
      VStack(spacing: 4) {
        Text(languageService.text(.expenseOverviewNetBalance))
          .font(SplickTheme.Typography.caption)
          .foregroundStyle(SplickTheme.Colors.textSecondary)
        Text(format(section.netBalance, currency: section.currency))
          .font(SplickTheme.Typography.title)
          .foregroundStyle(SplickTheme.Colors.textPrimary)
      }
      .frame(maxWidth: .infinity)
      if !section.topBalances.isEmpty {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
          ForEach(section.topBalances, id: \.user.id) { debt in
            HStack(spacing: SplickTheme.Spacing.sm) {
              AvatarView(imageURL: debt.user.avatarURL, name: debt.user.displayName, size: .small)
              Text(debt.user.displayName)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
              Spacer()
            Text(format(debt.amount, currency: debt.currency))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(
                  debt.amount >= 0 ? SplickTheme.Colors.success : SplickTheme.Colors.error
                )
            }
          }
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private func metric(title: String, amount: Decimal, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      Text(format(amount, currency: section.currency))
        .font(SplickTheme.Typography.headline)
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func format(_ amount: Decimal, currency: String) -> String {
    let symbol = Decimal.displayCurrencySymbol(for: currency)
    return "\(SplickMoneyFormat.string(from: amount.abs))\(symbol)"
  }
}

struct ExpenseNeedsAttentionSectionView: View {
  let section: ExpenseNeedsAttentionSection
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      HStack {
        Text(languageService.text(.expenseOverviewNeedsAttentionTitle))
          .font(SplickTheme.Typography.headline)
          .foregroundStyle(SplickTheme.Colors.textPrimary)
        Spacer()
        if section.totalActionItems > 0 {
          Text("\(section.totalActionItems)")
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(SplickTheme.Colors.error))
        }
      }
      if section.items.isEmpty {
        Text(languageService.text(.expenseOverviewNeedsAttentionEmpty))
          .font(SplickTheme.Typography.body)
          .foregroundStyle(SplickTheme.Colors.textSecondary)
      } else {
        ForEach(section.items) { item in
          HStack(spacing: SplickTheme.Spacing.sm) {
            if let user = item.counterparty {
              AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .small)
            }
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
              Text(typeLabel(item.type))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            Spacer()
            Text(format(item.amount, currency: item.currency))
              .font(SplickTheme.Typography.headline)
          }
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private func typeLabel(_ type: ExpenseNeedsAttentionType) -> String {
    switch type {
    case .paymentRequest: return languageService.text(.expenseOverviewPaymentRequest)
    case .expenseConfirmation: return languageService.text(.expenseOverviewExpenseConfirm)
    case .outstandingSettlement: return languageService.text(.expenseOverviewOutstandingSettlement)
    }
  }

  private func format(_ amount: Decimal, currency: String) -> String {
    let symbol = Decimal.displayCurrencySymbol(for: currency)
    return "\(SplickMoneyFormat.string(from: amount))\(symbol)"
  }
}

struct ExpenseRecentExpensesSectionView: View {
  let items: [RecentExpenseItem]
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      Text(languageService.text(.expenseOverviewRecentTitle))
        .font(SplickTheme.Typography.headline)
        .foregroundStyle(SplickTheme.Colors.textPrimary)
      if items.isEmpty {
        Text(languageService.text(.expenseOverviewRecentEmpty))
          .font(SplickTheme.Typography.body)
          .foregroundStyle(SplickTheme.Colors.textSecondary)
      } else {
        ForEach(items) { item in
          HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: item.paidBy.avatarURL, name: item.paidBy.displayName, size: .small)
            VStack(alignment: .leading, spacing: 2) {
              Text(item.description)
                .font(SplickTheme.Typography.body)
                .lineLimit(1)
              Text(item.category.title(using: languageService))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text(format(item.amount, currency: item.currency))
                .font(SplickTheme.Typography.headline)
              Text(item.createdAt.formatted(.relative(presentation: .named)))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
          }
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private func format(_ amount: Decimal, currency: String) -> String {
    let symbol = Decimal.displayCurrencySymbol(for: currency)
    return "\(SplickMoneyFormat.string(from: amount))\(symbol)"
  }
}

struct ExpenseTotalSpendingSectionView: View {
  let section: ExpenseTotalSpendingSection
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    VStack(spacing: SplickTheme.Spacing.sm) {
      Text(languageService.text(.expenseOverviewTotalSpendingTitle))
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      Text(format(section.currentPeriodTotal, currency: section.currency))
        .font(SplickTheme.Typography.largeTitle)
        .foregroundStyle(SplickTheme.Colors.textPrimary)
      let change = NSDecimalNumber(decimal: section.percentageChange).doubleValue
      Text(
        languageService.format(
          change >= 0 ? .expenseOverviewSpendingUp : .expenseOverviewSpendingDown,
          String(format: "%.1f", abs(change))
        )
      )
      .font(SplickTheme.Typography.caption)
      .foregroundStyle(change >= 0 ? SplickTheme.Colors.error : SplickTheme.Colors.success)
    }
    .frame(maxWidth: .infinity)
    .splickCard(padding: SplickTheme.Spacing.lg, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private func format(_ amount: Decimal, currency: String) -> String {
    let symbol = Decimal.displayCurrencySymbol(for: currency)
    return "\(SplickMoneyFormat.string(from: amount))\(symbol)"
  }
}

struct ExpenseSpendingChartsSectionView: View {
  let analytics: SpendingAnalytics?
  let state: LoadingState<SpendingAnalytics>
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      Text(languageService.text(.expenseOverviewSpendingTitle))
        .font(SplickTheme.Typography.headline)
      if let analytics, !analytics.trend.isEmpty {
        Chart(analytics.trend) { point in
          AreaMark(
            x: .value("Date", point.bucketStart),
            y: .value("Amount", NSDecimalNumber(decimal: point.amount).doubleValue)
          )
          .foregroundStyle(SplickTheme.Colors.primary.opacity(0.18))
          LineMark(
            x: .value("Date", point.bucketStart),
            y: .value("Amount", NSDecimalNumber(decimal: point.amount).doubleValue)
          )
          .foregroundStyle(SplickTheme.Colors.primary)
        }
        .frame(height: 160)
        if !analytics.categories.isEmpty {
          HStack(alignment: .center, spacing: SplickTheme.Spacing.md) {
            ExpenseCategoryDonut(categories: analytics.categories)
              .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 6) {
              ForEach(analytics.categories.prefix(5)) { category in
                HStack {
                  Text(category.category.title(using: languageService))
                    .font(SplickTheme.Typography.caption)
                  Spacer()
                  Text("\(category.percentage)%")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
              }
            }
          }
        }
      } else if case .loading = state {
        ProgressView()
          .frame(maxWidth: .infinity, minHeight: 80)
      } else {
        Text(languageService.text(.expenseOverviewSpendingEmpty))
          .font(SplickTheme.Typography.body)
          .foregroundStyle(SplickTheme.Colors.textSecondary)
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }
}

private struct ExpenseCategoryDonut: View {
  let categories: [SpendingCategoryBreakdown]

  var body: some View {
    Canvas { context, size in
      let total = categories.reduce(Decimal.zero) { $0 + $1.amount }
      guard total > 0 else { return }
      let radius = min(size.width, size.height) / 2
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      var start = Angle.degrees(-90)
      let colors: [Color] = [
        SplickTheme.Colors.primary,
        SplickTheme.Colors.success,
        SplickTheme.Colors.warning,
        SplickTheme.Colors.info,
        SplickTheme.Colors.error,
      ]
      for (index, category) in categories.enumerated() {
        let fraction = NSDecimalNumber(decimal: category.amount / total).doubleValue
        let end = start + Angle.degrees(360 * fraction)
        var path = Path()
        path.addArc(center: center, radius: radius - 10, startAngle: start, endAngle: end, clockwise: false)
        context.stroke(
          path,
          with: .color(colors[index % colors.count]),
          style: StrokeStyle(lineWidth: 16, lineCap: .butt)
        )
        start = end
      }
    }
  }
}

struct ExpenseGroupsSectionView: View {
  let groups: [GroupExpenseItem]
  let state: LoadingState<[GroupExpenseItem]>
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      Text(languageService.text(.expenseOverviewGroupsTitle))
        .font(SplickTheme.Typography.headline)
      if groups.isEmpty {
        if case .loading = state {
          ProgressView().frame(maxWidth: .infinity, minHeight: 60)
        } else {
          Text(languageService.text(.expenseOverviewGroupsEmpty))
            .font(SplickTheme.Typography.body)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
      } else {
        ForEach(groups) { group in
          VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack {
              AvatarView(imageURL: group.groupAvatarURL, name: group.groupName, size: .small)
              Text(group.groupName)
                .font(SplickTheme.Typography.headline)
              Spacer()
            }
            HStack {
              labeled(languageService.text(.expenseOverviewGroupTotal), group.totalGroupSpending, group.currency)
              labeled(languageService.text(.expenseOverviewGroupPaid), group.userPaidTotal, group.currency)
              labeled(languageService.text(.expenseOverviewGroupBalance), group.userBalance, group.currency)
            }
            HStack(spacing: -8) {
              ForEach(group.memberAvatars.prefix(5)) { member in
                AvatarView(imageURL: member.avatarURL, name: member.displayName, size: .small)
              }
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private func labeled(_ title: String, _ amount: Decimal, _ currency: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      Text(format(amount, currency: currency))
        .font(SplickTheme.Typography.caption)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func format(_ amount: Decimal, currency: String) -> String {
    let symbol = Decimal.displayCurrencySymbol(for: currency)
    return "\(SplickMoneyFormat.string(from: amount))\(symbol)"
  }
}

private extension Decimal {
  var abs: Decimal { self < 0 ? -self : self }
}
