import SwiftUI
import Combine
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureFriends

private struct ExpenseUserProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}

public struct ExpenseListView: View {
    @ObservedObject private var viewModel: ExpenseListViewModel
    @StateObject private var friendSearchViewModel: ExpenseUserSearchViewModel
    @State private var isOverviewExpanded = false
    @State private var showFilterPanel = false
    @State private var captionQueryDraft = ""
    @State private var friendQueryDraft = ""
    @State private var profileRoute: ExpenseUserProfileRoute?
    @State private var refreshController = SplickRefreshController()
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @Environment(\.openPostCaptureFlow) private var openPostCaptureFlow
    @Environment(\.openLinkedPost) private var openLinkedPost
    private let currentUserId: UUID?
    private let isTabActive: Bool
    private let profileDependencies: FriendUserProfileDependencies?

    private let overviewToggleAnimation = Animation.spring(response: 0.48, dampingFraction: 0.86)
    private let listFilterAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86)

    public init(
        viewModel: ExpenseListViewModel,
        currentUserId: UUID? = nil,
        isTabActive: Bool = true,
        userSearchUseCase: UserSearchUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil
    ) {
        self.viewModel = viewModel
        _friendSearchViewModel = StateObject(
            wrappedValue: ExpenseUserSearchViewModel(useCase: userSearchUseCase)
        )
        self.currentUserId = currentUserId
        self.isTabActive = isTabActive
        self.profileDependencies = profileDependencies
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.expenseLoading))

                case .loaded where viewModel.expenses.isEmpty:
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: languageService.text(.expenseEmptyTitle),
                        message: languageService.text(.expenseEmptyMessage),
                        actionTitle: languageService.text(.expenseEmptyAction)
                    ) {
                        openPostCapture()
                    }

                case .loaded:
                    expenseContent

                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .splickTabScreenHeader(languageService.text(.expenseTitle))
        }
        .onFirstAppear {
            viewModel.updateCurrentUserId(currentUserId)
            guard isTabActive else { return }
            Task { await viewModel.loadIfNeeded() }
        }
        .onChange(of: isTabActive) { active in
            guard active else { return }
            viewModel.updateCurrentUserId(currentUserId)
            Task { await viewModel.loadIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .paymentEvidenceStatusDidChange)) { _ in
            guard isTabActive else { return }
            Task { await viewModel.load(isPullToRefresh: true) }
        }
        .onChange(of: currentUserId) { userId in
            viewModel.updateCurrentUserId(userId)
        }
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(
                        user: route.user,
                        currentUserId: currentUserId
                    )
                )
            }
        }
    }

    private var expenseContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.md) {
                    Color.clear.frame(height: 0).id("expenseScrollTop")
                    debtSummarySection
                    expenseRecordsSection
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .transaction { transaction in
                    if pullToRefreshActive {
                        transaction.animation = nil
                    }
                }
            }
            .tabBarHideOnScroll()
            .splickNativeRefreshable(controller: refreshController) {
                await viewModel.load(isPullToRefresh: true)
            }
            .splickSameTabTapBehavior(
                scrollTopID: "expenseScrollTop",
                scrollProxy: proxy,
                refreshController: refreshController,
                isAtTop: { tabBarScrollState?.isAtTop == true },
                isEnabled: { isTabActive }
            )
            .onAppear {
                if captionQueryDraft.isEmpty {
                    captionQueryDraft = viewModel.filters.captionQuery
                }
            }
        }
    }

    private var expenseRecordsSection: some View {
        recordsSection {
            Group {
                if viewModel.displayedExpenses.isEmpty {
                    filteredEmptyState
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity
                            )
                        )
                } else {
                    expensesList(viewModel.displayedExpenses)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .move(edge: .bottom))
                            )
                        )
                }
            }
            .animation(pullToRefreshActive ? nil : listFilterAnimation, value: viewModel.filterSignature)
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            Text(languageService.text(.expenseFilteredEmptyTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
            Text(languageService.text(.expenseFilteredEmptyMessage))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SplickTheme.Spacing.xl)
        .splickCard(cornerRadius: ExpenseScreenChrome.cardRadius)
    }

    private var debtSummarySection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            overviewSectionHeader

            ExpenseOverviewAnimatedBody(isExpanded: isOverviewExpanded) {
                overviewDebtCharts(showsDetailedLegend: true)
            } collapsed: {
                overviewDebtCharts(showsDetailedLegend: false)
            }
        }
        .splickCard(
            padding: SplickTheme.Spacing.md,
            cornerRadius: ExpenseScreenChrome.cardRadius
        )
        .animation(pullToRefreshActive ? nil : overviewToggleAnimation, value: isOverviewExpanded)
    }

    private func overviewDebtCharts(showsDetailedLegend: Bool) -> some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.md) {
            ExpenseDebtDonutChart(
                title: languageService.text(.expenseYouOwe),
                unpaidAmount: viewModel.overviewOweUnpaidTotal,
                paidAmount: viewModel.overviewOwePaidTotal,
                unpaidCount: viewModel.overviewOweUnpaidCount,
                paidCount: viewModel.overviewOwePaidCount,
                unpaidFilter: .oweUnpaid,
                paidFilter: .owePaid,
                selectedFilter: viewModel.filters.debtStatus,
                showsDetailedLegend: showsDetailedLegend,
                unpaidLabel: languageService.text(.expenseOverviewUnpaid),
                paidLabel: languageService.text(.expenseOverviewPaid),
                emptyLabel: languageService.text(.expenseOverviewEmptyChart),
                countFormat: { languageService.format(.expenseOverviewOweUnpaidCount, $0) },
                filterHint: languageService.text(.expenseOverviewFilterHint),
                onSelect: viewModel.applyOverviewDebtFilter,
                onExpandRequest: expandOverviewIfNeeded
            )

            ExpenseDebtDonutChart(
                title: languageService.text(.expenseYouAreOwed),
                unpaidAmount: viewModel.overviewOwedUnpaidTotal,
                paidAmount: viewModel.overviewOwedPaidTotal,
                unpaidCount: viewModel.overviewOwedUnpaidCount,
                paidCount: viewModel.overviewOwedPaidCount,
                unpaidFilter: .owedUnpaid,
                paidFilter: .owedPaid,
                selectedFilter: viewModel.filters.debtStatus,
                showsDetailedLegend: showsDetailedLegend,
                unpaidLabel: languageService.text(.expenseOverviewUnpaid),
                paidLabel: languageService.text(.expenseOverviewPaid),
                emptyLabel: languageService.text(.expenseOverviewEmptyChart),
                countFormat: { languageService.format(.expenseOverviewOwedUnpaidCount, $0) },
                filterHint: languageService.text(.expenseOverviewFilterHint),
                onSelect: viewModel.applyOverviewDebtFilter,
                onExpandRequest: expandOverviewIfNeeded
            )
        }
    }

    private func expandOverviewIfNeeded() {
        guard !isOverviewExpanded else { return }
        withAnimation(overviewToggleAnimation) {
            isOverviewExpanded = true
        }
    }

    private var overviewSectionHeader: some View {
        Button {
            withAnimation(overviewToggleAnimation) {
                isOverviewExpanded.toggle()
            }
        } label: {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.info)
                    .frame(width: 22, height: 22)
                    .background {
                        Circle()
                            .fill(SplickTheme.Colors.info.opacity(0.14))
                    }

                HStack(spacing: SplickTheme.Spacing.xxxs) {
                    Text(languageService.text(.expenseOverviewSectionTitle))
                        .font(SplickTheme.Typography.captionBold)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .textCase(.uppercase)
                        .lineLimit(1)

                    if let periodLabel = datePeriodSubtitle {
                        Text(periodLabel)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .rotationEffect(.degrees(isOverviewExpanded ? 0 : -180))
            }
            .padding(.horizontal, SplickTheme.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.expenseOverviewSectionTitle))
        .accessibilityValue(
            [
                isOverviewExpanded
                    ? languageService.text(.expenseOverviewExpandedAccessibility)
                    : languageService.text(.expenseOverviewCollapsedAccessibility),
                datePeriodSubtitle
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        )
        .accessibilityHint(
            isOverviewExpanded
                ? languageService.text(.expenseOverviewCollapseHint)
                : languageService.text(.expenseOverviewExpandHint)
        )
    }

    private func recordsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            ExpenseListSectionHeader(
                title: languageService.text(.expenseRecordsSectionTitle),
                subtitle: datePeriodSubtitle,
                filterPanelTitle: languageService.text(.expenseFilterPanelTitle),
                filterClearTitle: languageService.text(.expenseFilterClear),
                showsFilterClear: viewModel.filters.hasNonDefaultListFilters,
                onClearFilters: {
                    captionQueryDraft = ""
                    friendQueryDraft = ""
                    friendSearchViewModel.reset(query: "")
                    viewModel.clearListFilters()
                },
                systemImage: "list.bullet.rectangle",
                accent: SplickTheme.Colors.primaryGradientStart,
                showsFilterBadge: viewModel.filters.hasNonDefaultListFilters,
                isFilterPresented: showFilterPanel,
                filterAccessibilityLabel: languageService.text(.expenseFilterOpenAccessibility),
                onFilterToggle: {
                    withAnimation(showFilterPanel ? SplickRevealMotion.collapse : SplickRevealMotion.expand) {
                        showFilterPanel.toggle()
                    }
                },
                filterPanel: {
                    ExpenseListFilterPanel(
                        viewModel: viewModel,
                        friendSearchViewModel: friendSearchViewModel,
                        captionQueryDraft: $captionQueryDraft,
                        friendQueryDraft: $friendQueryDraft,
                        languageService: languageService
                    )
                }
            )

            content()
        }
        .zIndex(showFilterPanel ? 1 : 0)
    }

    /// Shared period label shown beside overview and history section titles.
    private var datePeriodSubtitle: String? {
        switch viewModel.filters.activeDatePreset {
        case .week:
            return languageService.text(.expenseRecordsSectionThisWeek)
        case .month:
            return languageService.text(.expenseRecordsSectionThisMonth)
        case .all:
            return languageService.text(.expenseRecordsSectionAllTime)
        }
    }

    private func expensesList(_ expenses: [Expense]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                ExpenseRowView(
                    expense: expense,
                    currentUserId: currentUserId,
                    layout: .grouped,
                    onCreatorTap: {
                        openCreatorProfile(expense.paidBy)
                    }
                ) {
                    openLinkedPost(for: expense)
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    )
                )
                .animation(
                    pullToRefreshActive
                        ? nil
                        : listFilterAnimation.delay(listRowRevealDelay(index: index, total: expenses.count)),
                    value: viewModel.filterSignature
                )

                if index < expenses.count - 1 {
                    Divider()
                        .padding(.leading, 84)
                }
            }
        }
        .animation(
            pullToRefreshActive ? nil : listFilterAnimation,
            value: viewModel.displayedExpenses.map(\.id)
        )
        .background {
            RoundedRectangle(cornerRadius: ExpenseScreenChrome.cardRadius, style: .continuous)
                .fill(SplickTheme.Colors.cardBackground)
                .shadow(
                    color: SplickTheme.Shadow.card.color,
                    radius: SplickTheme.Shadow.card.radius,
                    x: SplickTheme.Shadow.card.x,
                    y: SplickTheme.Shadow.card.y
                )
                .overlay {
                    RoundedRectangle(cornerRadius: ExpenseScreenChrome.cardRadius, style: .continuous)
                        .strokeBorder(SplickTheme.Colors.primaryGradientStart.opacity(0.08), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: ExpenseScreenChrome.cardRadius, style: .continuous))
    }

    private func openPostCapture() {
        openPostCaptureFlow?()
    }

    private func openLinkedPost(for expense: Expense) {
        guard let postId = expense.postId else { return }
        openLinkedPost?(postId, true)
    }

    private func openCreatorProfile(_ user: UserSummary) {
        guard profileDependencies != nil else { return }
        profileRoute = ExpenseUserProfileRoute(user: user)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    private func listRowRevealDelay(index: Int, total: Int) -> Double {
        guard total > 1 else { return 0 }
        let distanceFromBottom = (total - 1) - index
        return Double(distanceFromBottom) * 0.045
    }
}

private struct ExpenseRowDescriptionText: View {
    @EnvironmentObject private var languageService: LanguageService

    let expense: Expense
    let currentUserId: UUID?
    let debtState: ExpenseUserDebtState
    let userCashFlow: ExpenseUserCashFlow

    private let bodyFont = Font.system(size: 13)

    var body: some View {
        Group {
            switch debtState {
            case .oweUnpaid, .owePaid:
                inlineActorMessage(
                    actorName: expense.paidBy.displayName,
                    lead: oweLead,
                    tail: nil
                )
            case .owedUnpaid, .owedPaid:
                inlineActorMessage(
                    actorName: counterpartyNames,
                    lead: nil,
                    tail: owedTail
                )
            case .neutral:
                (Text(languageService.text(.expenseRowDescNeutral))
                    .foregroundColor(SplickTheme.Colors.textSecondary)
                + amountTexts)
            }
        }
        .font(bodyFont)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .accessibilityLabel(accessibilityDescription)
    }

    private var oweLead: String {
        switch debtState {
        case .oweUnpaid:
            return languageService.text(.expenseRowDescOweUnpaidLead)
        case .owePaid:
            return languageService.text(.expenseRowDescOwePaidLead)
        default:
            return ""
        }
    }

    private var owedTail: String {
        switch debtState {
        case .owedUnpaid:
            return languageService.text(.expenseRowDescOwedUnpaidTail)
        case .owedPaid:
            return languageService.text(.expenseRowDescOwedPaidTail)
        default:
            return ""
        }
    }

    private var counterpartyNames: String {
        guard let currentUserId else {
            return expense.splits
                .filter { $0.user.id != expense.paidBy.id }
                .map(\.user.displayName)
                .joined(separator: ", ")
        }

        let relevantSplits: [ExpenseSplit]
        switch debtState {
        case .owedUnpaid:
            relevantSplits = expense.splits.filter { $0.user.id != currentUserId && !$0.isPaid }
        case .owedPaid:
            relevantSplits = expense.splits.filter { $0.user.id != currentUserId && $0.isPaid }
        default:
            relevantSplits = expense.splits.filter { $0.user.id != currentUserId }
        }

        return relevantSplits.map(\.user.displayName).joined(separator: ", ")
    }

    private var amountTexts: Text {
        let personalCompact = userCashFlow.amount.compactAmountString()
        let totalCompact = expense.totalAmount.compactAmountString()
        let currencySymbol = Decimal.currencySymbol(for: expense.currency)
        let personalWithUnit = "\(personalCompact)\(currencySymbol)"
        let totalWithUnit = "\(totalCompact)\(currencySymbol)"

        return Text(" \(personalWithUnit)")
            .fontWeight(.semibold)
            .foregroundColor(amountColor)
        + Text(" \(languageService.text(.expenseRowOfConnector)) ")
            .foregroundColor(SplickTheme.Colors.textSecondary)
        + Text(totalWithUnit)
            .fontWeight(.semibold)
            .foregroundColor(SplickTheme.Colors.textPrimary)
    }

    private var amountColor: Color {
        switch userCashFlow.direction {
        case .receiving:
            return SplickTheme.Colors.success
        case .paying:
            return SplickTheme.Colors.error
        case .neutral:
            return SplickTheme.Colors.textPrimary
        }
    }

    private var accessibilityDescription: String {
        let personal = formatAmount(userCashFlow.amount)
        let total = formatAmount(expense.totalAmount)
        let symbol = Decimal.currencySymbol(for: expense.currency)
        let amountPart = " \(personal)\(symbol) \(languageService.text(.expenseRowOfConnector)) \(total)\(symbol)"

        switch debtState {
        case .oweUnpaid:
            return languageService.text(.expenseRowDescOweUnpaidLead) + expense.paidBy.displayName + amountPart
        case .owePaid:
            return languageService.text(.expenseRowDescOwePaidLead) + expense.paidBy.displayName + amountPart
        case .owedUnpaid:
            return counterpartyNames + languageService.text(.expenseRowDescOwedUnpaidTail) + amountPart
        case .owedPaid:
            return counterpartyNames + languageService.text(.expenseRowDescOwedPaidTail) + amountPart
        case .neutral:
            return languageService.text(.expenseRowDescNeutral) + amountPart
        }
    }

    @ViewBuilder
    private func inlineActorMessage(actorName: String, lead: String?, tail: String?) -> some View {
        if let lead {
            (Text(lead)
                .foregroundColor(SplickTheme.Colors.textSecondary)
            + Text(actorName)
                .fontWeight(.semibold)
                .foregroundColor(SplickTheme.Colors.textPrimary)
            + amountTexts)
        } else if let tail {
            (Text(actorName)
                .fontWeight(.semibold)
                .foregroundColor(SplickTheme.Colors.textPrimary)
            + Text(tail)
                .foregroundColor(SplickTheme.Colors.textSecondary)
            + amountTexts)
        } else {
            Text(actorName)
                .fontWeight(.semibold)
                .foregroundColor(SplickTheme.Colors.textPrimary)
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = expense.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

struct ExpenseRowView: View {
    enum Layout {
        case grouped
        case standalone
    }

    @EnvironmentObject private var languageService: LanguageService
    let expense: Expense
    let currentUserId: UUID?
    var layout: Layout = .standalone
    let onCreatorTap: () -> Void
    let onTap: () -> Void

    private var isLinkedToPost: Bool {
        expense.postId != nil
    }

    private var userDebtState: ExpenseUserDebtState {
        expense.userDebtState(userId: currentUserId)
    }

    private var ageUrgency: ExpenseAgeUrgency {
        ExpenseAgeUrgency(createdAt: expense.createdAt)
    }

    private var userCashFlow: ExpenseUserCashFlow {
        expense.userCashFlow(userId: currentUserId)
    }

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            Button(action: onCreatorTap) {
                creatorAvatar
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                        if let caption = postCaptionHeader {
                            Text(caption)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(SplickTheme.Colors.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        ExpenseRowDescriptionText(
                            expense: expense,
                            currentUserId: currentUserId,
                            debtState: userDebtState,
                            userCashFlow: userCashFlow
                        )

                        Text(expense.createdAt.expenseListRelativeString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ageUrgency.color)
                            .lineLimit(1)
                            .padding(.horizontal, SplickTheme.Spacing.xs)
                            .padding(.vertical, 2)
                            .background {
                                Capsule()
                                    .fill(ageUrgency.color.opacity(0.12))
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    paymentStatusIcon
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ExpenseRowPressStyle())
            .disabled(!isLinkedToPost)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .modifier(ExpenseRowChromeModifier(layout: layout))
        .opacity(isLinkedToPost ? 1 : 0.55)
    }

    private var postCaptionHeader: String? {
        let caption = expense.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard expense.postId != nil, !caption.isEmpty else { return nil }
        return caption
    }

    private let avatarSize: CGFloat = 46

    private var creatorAvatar: some View {
        ZStack(alignment: .topTrailing) {
            AvatarView(
                imageURL: expense.paidBy.avatarURL,
                name: expense.paidBy.displayName,
                size: .medium,
                userId: expense.paidBy.id
            )
            .scaleEffect(avatarSize / 48)
            .frame(width: avatarSize, height: avatarSize)

            Text(languageService.text(.expenseRowCreatorLabel))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background {
                    Capsule()
                        .fill(SplickTheme.Colors.primaryGradientStart)
                }
                .offset(x: 4, y: -4)
        }
        .frame(width: avatarSize, height: avatarSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(creatorColumnAccessibilityLabel)
    }

    private var creatorColumnAccessibilityLabel: String {
        let name = expense.paidBy.displayName
        if expense.paidBy.id == currentUserId {
            return "\(languageService.text(.expenseRowCreatorLabel)), \(name), \(languageService.text(.expenseRowPaidByMe))"
        }
        return "\(languageService.text(.expenseRowCreatorLabel)), \(name)"
    }

    @ViewBuilder
    private var paymentStatusIcon: some View {
        Group {
            if userDebtState.isSettled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.success)
                    .accessibilityLabel(languageService.text(.expenseRowPaidAccessibility))
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.error)
                    .accessibilityLabel(languageService.text(.expenseRowUnpaidAccessibility))
            }
        }
        .frame(width: 32, height: 32)
    }
}

private struct ExpenseListSectionHeader<FilterPanel: View>: View {
    let title: String
    var subtitle: String?
    let filterPanelTitle: String
    let filterClearTitle: String
    var showsFilterClear: Bool = false
    var onClearFilters: (() -> Void)?
    let systemImage: String
    let accent: Color
    var showsFilterBadge: Bool = false
    let isFilterPresented: Bool
    let filterAccessibilityLabel: String
    let onFilterToggle: () -> Void
    @ViewBuilder let filterPanel: () -> FilterPanel

    private let controlSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: isFilterPresented ? SplickTheme.Spacing.md : 0) {
            ZStack(alignment: .topTrailing) {
                headerTitleRow
                cornerControl
            }

            if isFilterPresented {
                filterPanel()
                    .transition(
                        .scale(scale: 0.2, anchor: .topTrailing)
                            .combined(with: .opacity)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, SplickTheme.Spacing.md)
        .padding(.leading, isFilterPresented ? SplickTheme.Spacing.md : 0)
        .padding(.trailing, isFilterPresented ? SplickTheme.Spacing.md : 0)
        .padding(.bottom, isFilterPresented ? SplickTheme.Spacing.md : 0)
        .background {
            if isFilterPresented {
                RoundedRectangle(cornerRadius: ExpenseScreenChrome.cardRadius, style: .continuous)
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(
                        color: SplickTheme.Shadow.card.color,
                        radius: SplickTheme.Shadow.card.radius,
                        x: SplickTheme.Shadow.card.x,
                        y: SplickTheme.Shadow.card.y
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: ExpenseScreenChrome.cardRadius, style: .continuous)
                            .strokeBorder(accent.opacity(0.1), lineWidth: 1)
                    }
            }
        }
        .animation(SplickRevealMotion.expand, value: isFilterPresented)
    }

    private var headerTitleRow: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xs) {
            Image(systemName: isFilterPresented ? "slider.horizontal.3" : systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(accent.opacity(0.14))
                }

            Group {
                if isFilterPresented {
                    filterHeaderTitle
                } else {
                    recordsHeaderTitle
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, isFilterPresented ? 0 : SplickTheme.Spacing.xxs)
        .padding(.trailing, controlSize + SplickTheme.Spacing.xxxs)
        .animation(SplickRevealMotion.expand, value: isFilterPresented)
    }

    private var recordsHeaderTitle: some View {
        HStack(spacing: SplickTheme.Spacing.xxxs) {
            Text(title)
                .font(SplickTheme.Typography.captionBold)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .textCase(.uppercase)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var filterHeaderTitle: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Text(filterPanelTitle)
                .font(SplickTheme.Typography.captionBold)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .textCase(.uppercase)
                .lineLimit(1)

            if showsFilterClear, let onClearFilters {
                Button(filterClearTitle, action: onClearFilters)
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
    }

    private var cornerControl: some View {
        Button(action: onFilterToggle) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isFilterPresented ? "xmark" : "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(showsFilterBadge || isFilterPresented ? accent : SplickTheme.Colors.textSecondary)
                    .frame(width: controlSize, height: controlSize)
                    .background {
                        Circle()
                            .fill(
                                showsFilterBadge || isFilterPresented
                                    ? accent.opacity(0.14)
                                    : SplickTheme.Colors.secondaryBackground
                            )
                    }

                if showsFilterBadge && !isFilterPresented {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: -1)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, isFilterPresented ? 0 : SplickTheme.Spacing.md)
        .accessibilityLabel(filterAccessibilityLabel)
    }
}

private struct ExpenseListFilterPanel: View {
    @ObservedObject var viewModel: ExpenseListViewModel
    @ObservedObject var friendSearchViewModel: ExpenseUserSearchViewModel
    @Binding var captionQueryDraft: String
    @Binding var friendQueryDraft: String
    let languageService: LanguageService

    @State private var captionSearchTask: Task<Void, Never>?

    private var visibleFriendOptions: [UserSummary] {
        let query = friendQueryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return viewModel.filterParticipantUsers
        }
        return friendSearchViewModel.users
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                filterSectionLabel(languageService.text(.expenseFilterDateRange))
                HStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(ExpenseDatePreset.allCases) { preset in
                        filterPresetChip(preset)
                    }
                }
            }

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                filterSectionLabel(languageService.text(.expenseFilterSearchCaption))
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField(
                        languageService.text(.expenseFilterSearchCaption),
                        text: $captionQueryDraft
                    )
                    .font(SplickTheme.Typography.callout)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onChange(of: captionQueryDraft) { query in
                        scheduleCaptionSearch(query)
                    }

                    if !captionQueryDraft.isEmpty {
                        Button {
                            captionQueryDraft = ""
                            viewModel.setCaptionQuery("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: ExpenseScreenChrome.controlRadius, style: .continuous))
            }

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                filterSectionLabel(languageService.text(.expenseFilterFriends))

                if let selectedUser = viewModel.filters.selectedUser {
                    selectedFriendChip(selectedUser)
                }

                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField(
                        languageService.text(.expenseFilterSearchFriends),
                        text: $friendQueryDraft
                    )
                    .font(SplickTheme.Typography.callout)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: friendQueryDraft) { query in
                        friendSearchViewModel.reset(query: query)
                    }

                    if !friendQueryDraft.isEmpty {
                        Button {
                            friendQueryDraft = ""
                            friendSearchViewModel.reset(query: "")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: ExpenseScreenChrome.controlRadius, style: .continuous))

                friendsOptionsList
            }
            }
        }
        .onDisappear {
            captionSearchTask?.cancel()
        }
    }

    @ViewBuilder
    private var friendsOptionsList: some View {
        if friendSearchViewModel.isLoading && visibleFriendOptions.isEmpty {
            SplickSpinner(size: .small)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.xs)
        } else if visibleFriendOptions.isEmpty {
            Text(languageService.text(.expenseFilterNoFriends))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(visibleFriendOptions) { user in
                        userChip(user)
                            .onAppear {
                                Task { await friendSearchViewModel.loadMoreIfNeeded(current: user) }
                            }
                    }
                }
            }
        }
    }

    private func selectedFriendChip(_ user: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .small)
                .scaleEffect(0.78)
                .frame(width: 24, height: 24)

            Text(user.displayName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                viewModel.setSelectedUser(nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: ExpenseScreenChrome.controlRadius, style: .continuous))
    }

    private func filterSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SplickTheme.Colors.textTertiary)
            .textCase(.uppercase)
    }

    private func filterPresetChip(_ preset: ExpenseDatePreset) -> some View {
        let isSelected = viewModel.filters.activeDatePreset == preset
        return Button {
            viewModel.applyDatePreset(preset)
        } label: {
            Text(presetLabel(preset))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.primaryGradientStart
                        : SplickTheme.Colors.textSecondary
                )
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.xs)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? SplickTheme.Colors.primaryGradientStart.opacity(0.14)
                                : SplickTheme.Colors.secondaryBackground
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func presetLabel(_ preset: ExpenseDatePreset) -> String {
        switch preset {
        case .week:
            return languageService.text(.expenseFilterPresetWeek)
        case .month:
            return languageService.text(.expenseFilterPresetMonth)
        case .all:
            return languageService.text(.expenseFilterPresetAll)
        }
    }

    private func userChip(_ user: UserSummary) -> some View {
        let isSelected = viewModel.filters.selectedUser?.id == user.id
        return Button {
            if isSelected {
                viewModel.setSelectedUser(nil)
            } else {
                viewModel.setSelectedUser(user)
                friendQueryDraft = ""
                friendSearchViewModel.reset(query: "")
            }
        } label: {
            HStack(spacing: SplickTheme.Spacing.xxs) {
                AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .small)
                    .scaleEffect(0.78)
                    .frame(width: 24, height: 24)
                Text(user.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? SplickTheme.Colors.primaryGradientStart.opacity(0.14)
                            : SplickTheme.Colors.secondaryBackground
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? SplickTheme.Colors.primaryGradientStart.opacity(0.35)
                            : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func scheduleCaptionSearch(_ query: String) {
        captionSearchTask?.cancel()
        captionSearchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.setCaptionQuery(query)
            }
        }
    }
}

private struct ExpenseRowChromeModifier: ViewModifier {
    let layout: ExpenseRowView.Layout

    func body(content: Content) -> some View {
        switch layout {
        case .grouped:
            content
        case .standalone:
            content
                .splickCard(cornerRadius: ExpenseScreenChrome.cardRadius)
        }
    }
}

private struct ExpenseRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: ExpenseScreenChrome.insetRadius, style: .continuous)
                        .fill(SplickTheme.Colors.tertiaryBackground.opacity(0.7))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private enum ExpenseScreenChrome {
    /// Outer cards on the expense screen — softer than the global default.
    static let cardRadius: CGFloat = SplickTheme.CornerRadius.extraLarge
    /// Nested chart / filter containers inside cards.
    static let insetRadius: CGFloat = SplickTheme.CornerRadius.large
    /// Text fields and compact rows nested one level deeper.
    static let controlRadius: CGFloat = SplickTheme.CornerRadius.medium
}

private struct ExpenseOverviewAnimatedBody<Expanded: View, Collapsed: View>: View {
    let isExpanded: Bool
    @ViewBuilder var expanded: () -> Expanded
    @ViewBuilder var collapsed: () -> Collapsed

    var body: some View {
        Group {
            if isExpanded {
                expanded()
            } else {
                collapsed()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
    }
}

private struct ExpenseDebtDonutChart: View {
    let title: String
    let unpaidAmount: Decimal
    let paidAmount: Decimal
    let unpaidCount: Int
    let paidCount: Int
    let unpaidFilter: ExpenseDebtFilter
    let paidFilter: ExpenseDebtFilter
    let selectedFilter: ExpenseDebtFilter
    let showsDetailedLegend: Bool
    let unpaidLabel: String
    let paidLabel: String
    let emptyLabel: String
    let countFormat: (Int) -> String
    let filterHint: String
    let onSelect: (ExpenseDebtFilter) -> Void
    var onExpandRequest: (() -> Void)? = nil

    private var unpaidColor: Color { SplickTheme.Colors.error }
    private var paidColor: Color { SplickTheme.Colors.success }
    private let chartSize: CGFloat = 124
    private let ringWidth: CGFloat = 18
    private var chartCornerRadius: CGFloat { ExpenseScreenChrome.insetRadius }
    private var rowCornerRadius: CGFloat { ExpenseScreenChrome.controlRadius }

    private var totalAmount: Decimal { unpaidAmount + paidAmount }
    private var hasData: Bool { totalAmount > 0 }
    private var unpaidSelected: Bool { selectedFilter == unpaidFilter }
    private var paidSelected: Bool { selectedFilter == paidFilter }
    private var groupSelected: Bool { unpaidSelected || paidSelected }

    private var unpaidFraction: CGFloat {
        guard hasData else { return 0 }
        return CGFloat(NSDecimalNumber(decimal: unpaidAmount / totalAmount).doubleValue)
    }

    private var paidFraction: CGFloat { 1 - unpaidFraction }

    private func chartAmount(_ amount: Decimal) -> String {
        amount.chartAmountString(currencyCode: "VND")
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(SplickTheme.Typography.captionBold)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.bottom, SplickTheme.Spacing.md)

            donut
                .frame(width: chartSize, height: chartSize)
                .frame(maxWidth: .infinity)

            if showsDetailedLegend {
                VStack(spacing: SplickTheme.Spacing.xxs) {
                    detailRow(
                        label: unpaidLabel,
                        amount: unpaidAmount,
                        count: unpaidCount,
                        tint: unpaidColor,
                        filter: unpaidFilter,
                        isSelected: unpaidSelected
                    )
                    detailRow(
                        label: paidLabel,
                        amount: paidAmount,
                        count: paidCount,
                        tint: paidColor,
                        filter: paidFilter,
                        isSelected: paidSelected
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, SplickTheme.Spacing.md)
            }
        }
        .padding(SplickTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: chartCornerRadius, style: .continuous)
                .fill(SplickTheme.Colors.background.opacity(groupSelected ? 0.98 : 0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: chartCornerRadius, style: .continuous)
                        .strokeBorder(
                            SplickTheme.Colors.textTertiary.opacity(groupSelected ? 0.28 : 0.12),
                            lineWidth: groupSelected ? 1.5 : 1
                        )
                }
        }
    }

    private var donut: some View {
        ZStack {
            Circle()
                .stroke(SplickTheme.Colors.tertiaryBackground, lineWidth: ringWidth)

            if hasData {
                donutSlices
            }

            VStack(spacing: 2) {
                if hasData {
                    Text(chartAmount(totalAmount))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                        .allowsTightening(true)
                        .multilineTextAlignment(.center)
                } else {
                    Text(emptyLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
            .frame(width: chartSize - ringWidth * 2 - 4)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    if !showsDetailedLegend {
                        onExpandRequest?()
                        return
                    }
                    guard hasData else { return }
                    onSelect(filter(at: value.location))
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(filterHint)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var donutSlices: some View {
        let unpaidIsDominant = unpaidFraction >= paidFraction

        if unpaidIsDominant {
            // Smaller paid slice — rounded ends (under the larger C tips).
            if paidFraction > 0 {
                Circle()
                    .trim(from: unpaidFraction, to: 1)
                    .stroke(
                        paidColor,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(unpaidSelected && !paidSelected ? 0.35 : 1)
            }

            // Larger unpaid C — round tips sit over the junction.
            Circle()
                .trim(from: 0, to: unpaidFraction)
                .stroke(
                    unpaidColor,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(paidSelected && !unpaidSelected ? 0.35 : 1)
        } else {
            // Smaller unpaid slice — rounded ends (under the larger C tips).
            if unpaidFraction > 0 {
                Circle()
                    .trim(from: 0, to: unpaidFraction)
                    .stroke(
                        unpaidColor,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(paidSelected && !unpaidSelected ? 0.35 : 1)
            }

            // Larger paid C — round tips sit over the junction.
            Circle()
                .trim(from: unpaidFraction, to: 1)
                .stroke(
                    paidColor,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(unpaidSelected && !paidSelected ? 0.35 : 1)
        }
    }

    private func detailRow(
        label: String,
        amount: Decimal,
        count: Int,
        tint: Color,
        filter: ExpenseDebtFilter,
        isSelected: Bool
    ) -> some View {
        Button {
            onSelect(filter)
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: SplickTheme.Spacing.xxs) {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Text(chartAmount(amount))
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(countFormat(count))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .padding(.horizontal, SplickTheme.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
                    .fill(tint.opacity(isSelected ? 0.14 : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(chartAmount(amount)), \(countFormat(count))")
        .accessibilityHint(filterHint)
    }

    private func filter(at location: CGPoint) -> ExpenseDebtFilter {
        let center = CGPoint(x: chartSize / 2, y: chartSize / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let unpaidDegrees = Double(unpaidFraction) * 360
        return degrees <= unpaidDegrees ? unpaidFilter : paidFilter
    }

    private var accessibilitySummary: String {
        "\(title), \(unpaidLabel) \(chartAmount(unpaidAmount)), \(paidLabel) \(chartAmount(paidAmount))"
    }
}

private enum ExpenseAgeUrgency {
    case fresh
    case moderate
    case overdue

    init(createdAt: Date, relativeTo now: Date = .now) {
        let age = max(0, now.timeIntervalSince(createdAt))
        if age < 86_400 {
            self = .fresh
        } else if age < 86_400 * 3 {
            self = .moderate
        } else {
            self = .overdue
        }
    }

    var color: Color {
        switch self {
        case .fresh:
            return SplickTheme.Colors.success
        case .moderate:
            return SplickTheme.Colors.warning
        case .overdue:
            return SplickTheme.Colors.error
        }
    }
}
