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
  var onOpenNeedsAttentionItem: ((ExpenseNeedsAttentionItem) -> Void)? = nil
  var onOpenThisMonthHistory: (() -> Void)? = nil
  var onOpenGroupHistory: ((GroupExpenseItem) -> Void)? = nil

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
            ExpenseNeedsAttentionSectionView(
              section: overview.needsAttention,
              onOpenItem: onOpenNeedsAttentionItem
            )
            ExpenseTotalSpendingSectionView(
              section: overview.totalSpending,
              onOpenThisMonthHistory: onOpenThisMonthHistory
            )
          }
          ExpenseSpendingChartsSectionView(
            analytics: viewModel.analytics,
            state: viewModel.analyticsState
          )
          ExpenseGroupsSectionView(
            groups: viewModel.groups,
            state: viewModel.groupsState,
            onOpenGroup: onOpenGroupHistory
          )
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
  @State private var membersExpanded = false

  private static let collapsedMemberCount = 3

  var body: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      Text(languageService.text(.expenseOverviewBalanceTitle))
        .font(SplickTheme.Typography.headline)
        .foregroundStyle(SplickTheme.Colors.textPrimary)
      HStack(spacing: SplickTheme.Spacing.sm) {
        metric(
          title: languageService.text(.expenseYouOwe),
          amount: section.youOwe,
          color: SplickTheme.Colors.error,
          sign: .minus
        )
        metric(
          title: languageService.text(.expenseYouAreOwed),
          amount: section.owedToYou,
          color: SplickTheme.Colors.success,
          sign: .plus
        )
        metric(
          title: languageService.text(.expenseOverviewNetBalance),
          amount: section.netBalance,
          color: signedColor(section.netBalance),
          sign: .fromValue
        )
      }
      if !section.topBalances.isEmpty {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
          ForEach(visibleMembers, id: \.user.id) { debt in
            HStack(spacing: SplickTheme.Spacing.sm) {
              AvatarView(imageURL: debt.user.avatarURL, name: debt.user.displayName, size: .small)
              Text(debt.user.displayName)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
              Spacer()
              Text(formatSigned(debt.amount, currency: debt.currency))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(
                  debt.amount >= 0 ? SplickTheme.Colors.success : SplickTheme.Colors.error
                )
            }
          }
          if section.topBalances.count > Self.collapsedMemberCount {
            Button {
              withAnimation(.easeInOut(duration: 0.2)) {
                membersExpanded.toggle()
              }
            } label: {
              Text(toggleLabel)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityHint(
              languageService.text(
                membersExpanded ? .expenseOverviewCollapseHint : .expenseOverviewExpandHint
              )
            )
          }
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private var visibleMembers: [DebtSummary] {
    if membersExpanded {
      return section.topBalances
    }
    return Array(section.topBalances.prefix(Self.collapsedMemberCount))
  }

  private var toggleLabel: String {
    if membersExpanded {
      return languageService.text(.expenseOverviewShowLessPeople)
    }
    let remaining = section.topBalances.count - Self.collapsedMemberCount
    return languageService.format(.expenseOverviewSeeMorePeople, remaining)
  }

  private func metric(title: String, amount: Decimal, color: Color, sign: AmountSign) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Text(formatSigned(amount, currency: section.currency, sign: sign))
        .font(SplickTheme.Typography.headline)
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func format(_ amount: Decimal, currency: String) -> String {
    overviewAmountBody(amount, currency: currency)
  }

  private func formatSigned(
    _ amount: Decimal,
    currency: String,
    sign: AmountSign = .fromValue
  ) -> String {
    overviewSignedAmount(amount, currency: currency, sign: sign)
  }
}

private enum AmountSign {
  case plus
  case minus
  case fromValue
}

private func overviewAmountBody(_ amount: Decimal, currency: String) -> String {
  let symbol = Decimal.displayCurrencySymbol(for: currency)
  return "\(SplickMoneyFormat.string(from: amount.abs))\(symbol)"
}

private func overviewSignedAmount(
  _ amount: Decimal,
  currency: String,
  sign: AmountSign = .fromValue
) -> String {
  let body = overviewAmountBody(amount, currency: currency)
  guard amount != 0 else { return body }
  switch sign {
  case .plus:
    return "+\(body)"
  case .minus:
    return "-\(body)"
  case .fromValue:
    return amount > 0 ? "+\(body)" : "-\(body)"
  }
}

private func signedColor(_ amount: Decimal, sign: AmountSign = .fromValue) -> Color {
  switch sign {
  case .plus:
    return SplickTheme.Colors.success
  case .minus:
    return SplickTheme.Colors.error
  case .fromValue:
    if amount > 0 { return SplickTheme.Colors.success }
    if amount < 0 { return SplickTheme.Colors.error }
    return SplickTheme.Colors.textPrimary
  }
}

struct ExpenseNeedsAttentionSectionView: View {
  let section: ExpenseNeedsAttentionSection
  var onOpenItem: ((ExpenseNeedsAttentionItem) -> Void)? = nil
  @EnvironmentObject private var languageService: LanguageService

  private static let previewLimit = 3

  private var previewItems: [ExpenseNeedsAttentionItem] {
    Array(section.items.prefix(Self.previewLimit))
  }

  private var remainingCount: Int {
    max(0, max(section.totalActionItems, section.items.count) - Self.previewLimit)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      HStack {
        Text(languageService.text(.expenseOverviewNeedsAttentionTitle))
          .font(SplickTheme.Typography.headline)
          .foregroundStyle(SplickTheme.Colors.textPrimary)
        Spacer()
        if !section.items.isEmpty {
          NavigationLink {
            ExpenseNeedsAttentionListView(items: section.items, onOpenItem: onOpenItem)
          } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
              if remainingCount > 0 {
                Text("+\(remainingCount)")
                  .font(SplickTheme.Typography.caption)
                  .foregroundStyle(SplickTheme.Colors.textSecondary)
              }
              Image(systemName: "chevron.right")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(languageService.text(.expenseOverviewNeedsAttentionTitle))
        }
      }
      if section.items.isEmpty {
        Text(languageService.text(.expenseOverviewNeedsAttentionEmpty))
          .font(SplickTheme.Typography.body)
          .foregroundStyle(SplickTheme.Colors.textSecondary)
      } else {
        ForEach(previewItems, id: \.rowIdentity) { item in
          ExpenseNeedsAttentionRowView(item: item, onOpen: onOpenItem)
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }
}

struct ExpenseNeedsAttentionListView: View {
  let items: [ExpenseNeedsAttentionItem]
  var onOpenItem: ((ExpenseNeedsAttentionItem) -> Void)? = nil
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
        ForEach(items, id: \.rowIdentity) { item in
          ExpenseNeedsAttentionRowView(item: item, onOpen: onOpenItem)
        }
      }
      .padding(.horizontal, SplickTheme.Spacing.md)
      .padding(.top, SplickTheme.Spacing.md)
      .padding(.bottom, SplickTabBarMetrics.floatingClearance + SplickTheme.Spacing.md)
    }
    .background(SplickTheme.Colors.background.ignoresSafeArea())
    .navigationTitle(languageService.text(.expenseOverviewNeedsAttentionTitle))
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct ExpenseNeedsAttentionRowView: View {
  let item: ExpenseNeedsAttentionItem
  var onOpen: ((ExpenseNeedsAttentionItem) -> Void)? = nil
  @EnvironmentObject private var languageService: LanguageService
  @Environment(\.openLinkedPost) private var openLinkedPost

  var body: some View {
    Button(action: openItem) {
      rowContent
    }
    .buttonStyle(.plain)
    .disabled(!canOpen)
  }

  private var canOpen: Bool {
    onOpen != nil || item.postId != nil || item.counterparty != nil
  }

  private func openItem() {
    if let onOpen {
      onOpen(item)
      return
    }
    if let postId = item.postId {
      openLinkedPost?(postId, true)
    }
  }

  private var rowContent: some View {
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
      Text(overviewSignedAmount(item.amount, currency: item.currency, sign: amountSign))
        .font(SplickTheme.Typography.headline)
        .foregroundStyle(signedColor(item.amount, sign: amountSign))
    }
    .contentShape(Rectangle())
  }

  private var amountSign: AmountSign {
    switch item.type {
    case .paymentRequest: return .minus
    case .expenseConfirmation: return .plus
    case .outstandingSettlement: return .fromValue
    }
  }

  private func typeLabel(_ type: ExpenseNeedsAttentionType) -> String {
    switch type {
    case .paymentRequest: return languageService.text(.expenseOverviewPaymentRequest)
    case .expenseConfirmation: return languageService.text(.expenseOverviewExpenseConfirm)
    case .outstandingSettlement: return languageService.text(.expenseOverviewOutstandingSettlement)
    }
  }
}

struct ExpenseTotalSpendingSectionView: View {
  let section: ExpenseTotalSpendingSection
  var onOpenThisMonthHistory: (() -> Void)? = nil
  @EnvironmentObject private var languageService: LanguageService

  var body: some View {
    VStack(spacing: SplickTheme.Spacing.sm) {
      Text(languageService.text(.expenseOverviewTotalSpendingTitle))
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      Text(overviewSignedAmount(section.currentPeriodTotal, currency: section.currency, sign: .minus))
        .font(SplickTheme.Typography.largeTitle)
        .foregroundStyle(SplickTheme.Colors.error)
      let change = NSDecimalNumber(decimal: section.percentageChange).doubleValue
      Text(
        languageService.format(
          change >= 0 ? .expenseOverviewSpendingUp : .expenseOverviewSpendingDown,
          String(format: "%.1f", abs(change))
        )
      )
      .font(SplickTheme.Typography.caption)
      .foregroundStyle(change >= 0 ? SplickTheme.Colors.error : SplickTheme.Colors.success)
      if let onOpenThisMonthHistory {
        Button(action: onOpenThisMonthHistory) {
          HStack(spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.expenseOverviewViewSpendingDetails))
              .font(SplickTheme.Typography.caption)
            Image(systemName: "chevron.right")
              .font(SplickTheme.Typography.caption)
          }
          .foregroundStyle(SplickTheme.Colors.primary)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity)
    .splickCard(padding: SplickTheme.Spacing.lg, cornerRadius: ExpenseScreenChrome.cardRadius)
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
        if let top = analytics.categories.first {
          Text(
            languageService.format(
              .expenseOverviewTopCategory,
              top.category.title(using: languageService),
              spendingPercentLabel(top.percentage)
            )
          )
          .font(SplickTheme.Typography.caption)
          .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        labeledBlock(languageService.text(.expenseOverviewTrendTitle)) {
          ExpenseSpendingTrendChart(
            trend: monthlyTrend(from: analytics.trend),
            monthLabel: spendingMonthLabel
          )
            .frame(height: 180)
            .accessibilityLabel(languageService.text(.expenseOverviewTrendTitle))
        }
        if !analytics.categories.isEmpty {
          labeledBlock(languageService.text(.expenseOverviewCategoryTitle)) {
            let maxAmount = analytics.categories.map(\.amount).max() ?? 1
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
              ForEach(Array(analytics.categories.prefix(5).enumerated()), id: \.element.id) { index, category in
                ExpenseSpendBarRow(
                  label: category.category.title(using: languageService),
                  amountText: overviewSignedAmount(category.amount, currency: analytics.currency, sign: .minus),
                  fraction: spendingBarFraction(category.amount, of: maxAmount),
                  barColor: spendingCategoryColor(index),
                  accessory: "\(spendingPercentLabel(category.percentage))%"
                )
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

  private func monthlyTrend(from points: [SpendingTrendPoint]) -> [SpendingTrendPoint] {
    let calendar = Calendar(identifier: .gregorian)
    var totals: [Date: Decimal] = [:]
    for point in points {
      var components = calendar.dateComponents([.year, .month], from: point.bucketStart)
      components.day = 1
      components.hour = 0
      components.minute = 0
      components.second = 0
      guard let monthStart = calendar.date(from: components) else { continue }
      totals[monthStart, default: 0] += point.amount
    }
    return totals.keys.sorted().map { date in
      SpendingTrendPoint(bucketStart: date, amount: totals[date] ?? 0)
    }
  }

  private func labeledBlock<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
      Text(title)
        .font(SplickTheme.Typography.callout)
        .fontWeight(.semibold)
      content()
    }
  }

  private func spendingMonthLabel(_ date: Date) -> String {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)
    switch languageService.locale {
    case .vi:
      return "Tháng \(month)/\(year)"
    case .en:
      return date.formatted(
        Date.FormatStyle(locale: Locale(identifier: "en")).month(.abbreviated).year()
      )
    }
  }
}

private struct ExpenseSpendingTrendChart: View {
  let trend: [SpendingTrendPoint]
  var monthLabel: (Date) -> String = { date in
    date.formatted(Date.FormatStyle().month(.abbreviated).year())
  }

  private var yMax: Double {
    let peak = trend
      .map { NSDecimalNumber(decimal: $0.amount).doubleValue }
      .max() ?? 0
    return max(peak, 1)
  }

  var body: some View {
    Chart(trend) { point in
      AreaMark(
        x: .value("Month", point.bucketStart),
        y: .value("Amount", NSDecimalNumber(decimal: point.amount).doubleValue)
      )
      .foregroundStyle(SplickTheme.Colors.primary.opacity(0.18))
      LineMark(
        x: .value("Month", point.bucketStart),
        y: .value("Amount", NSDecimalNumber(decimal: point.amount).doubleValue)
      )
      .foregroundStyle(SplickTheme.Colors.primary)
      PointMark(
        x: .value("Month", point.bucketStart),
        y: .value("Amount", NSDecimalNumber(decimal: point.amount).doubleValue)
      )
      .foregroundStyle(SplickTheme.Colors.primary)
      .symbolSize(36)
    }
    .chartYScale(domain: 0...yMax)
    .chartXAxis {
      AxisMarks(values: trend.map(\.bucketStart)) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel {
          if let date = value.as(Date.self) {
            Text(monthLabel(date))
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
        AxisGridLine()
        AxisValueLabel {
          if let amount = value.as(Double.self) {
            Text(Decimal(amount).compactAmountString())
              .font(SplickTheme.Typography.caption)
          }
        }
      }
    }
  }
}

private struct ExpenseSpendBarRow: View {
  let label: String
  let amountText: String
  let fraction: CGFloat
  var barColor: Color = SplickTheme.Colors.primary
  var accessory: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(label)
          .font(SplickTheme.Typography.caption)
          .foregroundStyle(SplickTheme.Colors.textPrimary)
          .lineLimit(1)
        Spacer(minLength: 8)
        if let accessory {
          Text(accessory)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        Text(amountText)
          .font(SplickTheme.Typography.caption)
          .fontWeight(.semibold)
          .foregroundStyle(SplickTheme.Colors.error)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(SplickTheme.Colors.secondaryBackground)
          Capsule()
            .fill(barColor)
            .frame(width: max(8, geo.size.width * fraction))
        }
      }
      .frame(height: 8)
    }
    .accessibilityElement(children: .combine)
  }
}

private func spendingBarFraction(_ amount: Decimal, of maxAmount: Decimal) -> CGFloat {
  guard maxAmount > 0 else { return 0 }
  return CGFloat(NSDecimalNumber(decimal: amount / maxAmount).doubleValue)
}

private func spendingPercentLabel(_ value: Decimal) -> String {
  "\(NSDecimalNumber(decimal: value).intValue)"
}

private func spendingCategoryColor(_ index: Int) -> Color {
  let colors: [Color] = [
    SplickTheme.Colors.primary,
    SplickTheme.Colors.success,
    SplickTheme.Colors.warning,
    SplickTheme.Colors.info,
    SplickTheme.Colors.error,
  ]
  return colors[index % colors.count]
}

struct ExpenseGroupsSectionView: View {
  let groups: [GroupExpenseItem]
  let state: LoadingState<[GroupExpenseItem]>
  var onOpenGroup: ((GroupExpenseItem) -> Void)? = nil
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
        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
          if index > 0 {
            Rectangle()
              .fill(SplickTheme.Colors.divider.opacity(0.45))
              .frame(height: 0.5)
          }
          groupRow(group)
        }
      }
    }
    .splickCard(padding: SplickTheme.Spacing.md, cornerRadius: ExpenseScreenChrome.cardRadius)
  }

  private func groupRow(_ group: GroupExpenseItem) -> some View {
    Button {
      onOpenGroup?(group)
    } label: {
      VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
        HStack {
          AvatarView(imageURL: group.groupAvatarURL, name: group.groupName, size: .small)
          Text(group.groupName)
            .font(SplickTheme.Typography.headline)
            .foregroundStyle(SplickTheme.Colors.textPrimary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        HStack {
          labeled(
            languageService.text(.expenseOverviewGroupTotal),
            group.totalGroupSpending,
            group.currency,
            sign: .minus
          )
          labeled(
            languageService.text(.expenseOverviewGroupPaid),
            group.userPaidTotal,
            group.currency,
            sign: .minus
          )
          labeled(
            languageService.text(.expenseOverviewGroupBalance),
            group.userBalance,
            group.currency,
            sign: .fromValue
          )
        }
        HStack(spacing: -8) {
          ForEach(group.memberAvatars.prefix(5)) { member in
            AvatarView(imageURL: member.avatarURL, name: member.displayName, size: .small)
          }
        }
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(onOpenGroup == nil)
  }

  private func labeled(
    _ title: String,
    _ amount: Decimal,
    _ currency: String,
    sign: AmountSign
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(SplickTheme.Colors.textSecondary)
      Text(overviewSignedAmount(amount, currency: currency, sign: sign))
        .font(SplickTheme.Typography.caption)
        .foregroundStyle(signedColor(amount, sign: sign))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private extension Decimal {
  var abs: Decimal { self < 0 ? -self : self }
}
