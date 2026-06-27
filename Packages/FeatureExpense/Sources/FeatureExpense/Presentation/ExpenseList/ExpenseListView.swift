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
    @StateObject private var viewModel: ExpenseListViewModel
    @StateObject private var friendSearchViewModel: ExpenseUserSearchViewModel
    @State private var isOverviewExpanded = false
    @State private var showFilterPanel = false
    @State private var captionQueryDraft = ""
    @State private var friendQueryDraft = ""
    @State private var profileRoute: ExpenseUserProfileRoute?
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.openPostCaptureFlow) private var openPostCaptureFlow
    @Environment(\.openLinkedPost) private var openLinkedPost
    @Environment(\.openProfileSettings) private var openProfileSettings
    private let currentUserId: UUID?
    private let profileDependencies: FriendUserProfileDependencies?

    private let overviewToggleAnimation = Animation.spring(response: 0.48, dampingFraction: 0.86)
    private let listFilterAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86)

    public init(
        viewModel: @autoclosure @escaping () -> ExpenseListViewModel,
        currentUserId: UUID? = nil,
        userSearchUseCase: UserSearchUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        _friendSearchViewModel = StateObject(
            wrappedValue: ExpenseUserSearchViewModel(useCase: userSearchUseCase)
        )
        self.currentUserId = currentUserId
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
            .refreshable { await viewModel.load(isPullToRefresh: true) }
        }
        .onFirstAppear {
            viewModel.updateCurrentUserId(currentUserId)
            Task { await viewModel.load() }
        }
        .onChange(of: currentUserId) { userId in
            viewModel.updateCurrentUserId(userId)
        }
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(user: route.user)
                )
            }
        }
    }

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
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
            }
            .tabBarHideOnScroll()
            .onAppear {
                if captionQueryDraft.isEmpty {
                    captionQueryDraft = viewModel.filters.captionQuery
                }
            }
            .onReceive(sameTabTapPublisher) { _ in
                if tabBarScrollState?.isAtTop == true {
                    Task { await viewModel.load(isPullToRefresh: true) }
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        proxy.scrollTo("expenseScrollTop", anchor: .top)
                    }
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
            .animation(listFilterAnimation, value: viewModel.filterSignature)
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
        .splickCard()
    }

    private var debtSummarySection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            overviewSectionHeader

            ExpenseOverviewAnimatedBody(isExpanded: isOverviewExpanded) {
                VStack(spacing: SplickTheme.Spacing.sm) {
                    debtSummaryRow(
                        title: languageService.text(.expenseYouAreOwed),
                        peopleSubtitle: languageService.format(
                            .expenseOverviewOwedPeopleCount,
                            viewModel.overviewOwedPeopleCount
                        ),
                        amount: viewModel.overviewTotalOwed,
                        tint: SplickTheme.Colors.success,
                        systemImage: "arrow.down.circle.fill",
                        filter: .owed,
                        isSelected: viewModel.filters.debtStatus == .owed
                    )
                    debtSummaryRow(
                        title: languageService.text(.expenseYouOwe),
                        peopleSubtitle: languageService.format(
                            .expenseOverviewOwingPeopleCount,
                            viewModel.overviewOwingPeopleCount
                        ),
                        amount: viewModel.overviewTotalOwing,
                        tint: SplickTheme.Colors.error,
                        systemImage: "arrow.up.circle.fill",
                        filter: .owe,
                        isSelected: viewModel.filters.debtStatus == .owe
                    )
                }
            } collapsed: {
                overviewCollapsedSummary
            }
        }
        .padding(SplickTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            SplickTheme.Colors.success.opacity(0.1),
                            SplickTheme.Colors.error.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    SplickTheme.Colors.success.opacity(0.22),
                                    SplickTheme.Colors.error.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .animation(overviewToggleAnimation, value: isOverviewExpanded)
    }

    private var overviewSectionHeader: some View {
        Button {
            withAnimation(overviewToggleAnimation) {
                isOverviewExpanded.toggle()
            }
        } label: {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.info)
                    .frame(width: 22, height: 22)
                    .background {
                        Circle()
                            .fill(SplickTheme.Colors.info.opacity(0.14))
                    }

                Text(languageService.text(.expenseOverviewSectionTitle))
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .lineLimit(1)

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
            isOverviewExpanded
                ? languageService.text(.expenseOverviewExpandedAccessibility)
                : languageService.text(.expenseOverviewCollapsedAccessibility)
        )
        .accessibilityHint(
            isOverviewExpanded
                ? languageService.text(.expenseOverviewCollapseHint)
                : languageService.text(.expenseOverviewExpandHint)
        )
    }

    private var overviewCollapsedSummary: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            overviewCollapsedMetric(
                title: languageService.text(.expenseYouAreOwed),
                amount: viewModel.overviewTotalOwed,
                tint: SplickTheme.Colors.success,
                filter: .owed,
                isSelected: viewModel.filters.debtStatus == .owed
            )
            overviewCollapsedMetric(
                title: languageService.text(.expenseYouOwe),
                amount: viewModel.overviewTotalOwing,
                tint: SplickTheme.Colors.error,
                filter: .owe,
                isSelected: viewModel.filters.debtStatus == .owe
            )
        }
        .padding(.horizontal, SplickTheme.Spacing.xxs)
    }

    private func overviewCollapsedMetric(
        title: String,
        amount: Decimal,
        tint: Color,
        filter: ExpenseDebtFilter,
        isSelected: Bool
    ) -> some View {
        Button {
            viewModel.applyOverviewDebtFilter(filter)
        } label: {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(title)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
                Text(formatAmount(amount))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SplickTheme.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                    .fill(SplickTheme.Colors.background.opacity(isSelected ? 0.98 : 0.88))
                    .overlay {
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                            .strokeBorder(tint.opacity(isSelected ? 0.38 : 0.16), lineWidth: isSelected ? 1.5 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(formatAmount(amount))")
        .accessibilityHint(languageService.text(.expenseOverviewFilterHint))
    }

    private func recordsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            ExpenseListSectionHeader(
                title: languageService.text(.expenseRecordsSectionTitle),
                subtitle: recordsSectionSubtitle,
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

    private var recordsSectionSubtitle: String? {
        switch viewModel.filters.activeDatePreset {
        case .week:
            return languageService.text(.expenseRecordsSectionThisWeek)
        case .month:
            return languageService.text(.expenseRecordsSectionThisMonth)
        case .all:
            return languageService.text(.expenseRecordsSectionAllTime)
        }
    }

    private func debtSummaryRow(
        title: String,
        peopleSubtitle: String,
        amount: Decimal,
        tint: Color,
        systemImage: String,
        filter: ExpenseDebtFilter,
        isSelected: Bool
    ) -> some View {
        Button {
            viewModel.applyOverviewDebtFilter(filter)
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                            .fill(tint.opacity(isSelected ? 0.2 : 0.12))
                    }

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                    Text(title)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    Text(peopleSubtitle)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                    Text(formatAmount(amount))
                        .font(SplickTheme.Typography.title)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "line.3.horizontal.decrease.circle.fill" : "chevron.right")
                    .font(.system(size: isSelected ? 18 : 12, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : SplickTheme.Colors.textTertiary)
            }
            .padding(SplickTheme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                    .fill(SplickTheme.Colors.background.opacity(0.92))
                    .overlay {
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                            .strokeBorder(tint.opacity(isSelected ? 0.38 : 0.16), lineWidth: isSelected ? 1.5 : 1)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                    .strokeBorder(tint.opacity(isSelected ? 0.45 : 0), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(peopleSubtitle), \(formatAmount(amount))")
        .accessibilityHint(languageService.text(.expenseOverviewFilterHint))
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
                    listFilterAnimation.delay(listRowRevealDelay(index: index, total: expenses.count)),
                    value: viewModel.filterSignature
                )

                if index < expenses.count - 1 {
                    Divider()
                        .padding(.leading, 84)
                }
            }
        }
        .animation(listFilterAnimation, value: viewModel.displayedExpenses.map(\.id))
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .fill(SplickTheme.Colors.cardBackground)
                .shadow(
                    color: SplickTheme.Shadow.card.color,
                    radius: SplickTheme.Shadow.card.radius,
                    x: SplickTheme.Shadow.card.x,
                    y: SplickTheme.Shadow.card.y
                )
                .overlay {
                    RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                        .strokeBorder(SplickTheme.Colors.primaryGradientStart.opacity(0.08), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
    }

    private func openPostCapture() {
        openPostCaptureFlow?()
    }

    private func openLinkedPost(for expense: Expense) {
        guard let postId = expense.postId else { return }
        openLinkedPost?(postId, true)
    }

    private func openCreatorProfile(_ user: UserSummary) {
        if user.id == currentUserId {
            openProfileSettings?()
            return
        }
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

    private var isPaidForCurrentUser: Bool {
        expense.isPaidFor(userId: currentUserId)
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
                creatorColumn
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                        if let caption = postCaptionHeader {
                            Text(caption)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        combinedAmountLine

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

    private var isCurrentUserPayer: Bool {
        guard let currentUserId else { return false }
        return expense.paidBy.id == currentUserId
    }

    private var creatorColumn: some View {
        VStack(spacing: SplickTheme.Spacing.xxxs) {
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

            HStack(spacing: 2) {
                Text(expense.paidBy.displayName.givenNameOnly)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                if isCurrentUserPayer {
                    Text(languageService.text(.expenseRowPaidByMe))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: 68)
        }
        .frame(width: 68)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(creatorColumnAccessibilityLabel)
    }

    private var creatorColumnAccessibilityLabel: String {
        let name = expense.paidBy.displayName
        if isCurrentUserPayer {
            return "\(languageService.text(.expenseRowCreatorLabel)), \(name), \(languageService.text(.expenseRowPaidByMe))"
        }
        return "\(languageService.text(.expenseRowCreatorLabel)), \(name)"
    }

    @ViewBuilder
    private var paymentStatusIcon: some View {
        Group {
            if isPaidForCurrentUser {
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

    private var combinedAmountLine: some View {
        let personalCompact = userCashFlow.amount.compactAmountString()
        let totalCompact = expense.totalAmount.compactAmountString()
        let currencySymbol = Decimal.currencySymbol(for: expense.currency)
        let verb = amountVerb
        let personalColor = amountColor(for: userCashFlow.direction)
        let personalWithUnit = "\(personalCompact)\(currencySymbol)"
        let totalWithUnit = "\(totalCompact)\(currencySymbol)"

        return HStack(spacing: 0) {
            Text("\(verb) ")
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Text(personalWithUnit)
                .foregroundStyle(personalColor)
                .fontWeight(.semibold)

            Text(" \(languageService.text(.expenseRowOfConnector)) ")
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Text(totalWithUnit)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .fontWeight(.semibold)
        }
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .accessibilityLabel(combinedAmountAccessibilityLabel)
    }

    private var amountVerb: String {
        switch userCashFlow.direction {
        case .paying:
            return languageService.text(.expenseRowPayVerb)
        case .receiving:
            return languageService.text(.expenseRowReceiveVerb)
        case .neutral:
            return languageService.text(.expenseRowShareVerb)
        }
    }

    private var combinedAmountAccessibilityLabel: String {
        let personal = formatAmount(userCashFlow.amount)
        let total = formatAmount(expense.totalAmount)
        let symbol = Decimal.currencySymbol(for: expense.currency)
        return "\(amountVerb) \(personal)\(symbol) \(languageService.text(.expenseRowOfConnector)) \(total)\(symbol)"
    }

    private func amountColor(for direction: ExpenseUserCashFlow.Direction) -> Color {
        switch direction {
        case .receiving:
            return SplickTheme.Colors.success
        case .paying:
            return SplickTheme.Colors.error
        case .neutral:
            return SplickTheme.Colors.textPrimary
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

private struct ExpenseListSectionHeader<FilterPanel: View>: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let accent: Color
    var showsFilterBadge: Bool = false
    let isFilterPresented: Bool
    let filterAccessibilityLabel: String
    let onFilterToggle: () -> Void
    @ViewBuilder let filterPanel: () -> FilterPanel

    private let controlSize: CGFloat = 30

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: isFilterPresented ? SplickTheme.Spacing.md : 0) {
                headerTitleRow

                if isFilterPresented {
                    filterPanel()
                        .transition(
                            .scale(scale: 0.2, anchor: .topTrailing)
                                .combined(with: .opacity)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, isFilterPresented ? SplickTheme.Spacing.md : SplickTheme.Spacing.xxs)
            .padding(.trailing, isFilterPresented ? SplickTheme.Spacing.md + controlSize + SplickTheme.Spacing.xxs : SplickTheme.Spacing.xxs)
            .padding(.vertical, isFilterPresented ? SplickTheme.Spacing.md : 0)

            cornerControl
        }
        .background {
            if isFilterPresented {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(
                        color: SplickTheme.Shadow.card.color,
                        radius: SplickTheme.Shadow.card.radius,
                        x: SplickTheme.Shadow.card.x,
                        y: SplickTheme.Shadow.card.y
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                            .strokeBorder(accent.opacity(0.1), lineWidth: 1)
                    }
            }
        }
        .animation(SplickRevealMotion.expand, value: isFilterPresented)
    }

    private var headerTitleRow: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(accent.opacity(0.14))
                }

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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, isFilterPresented ? 0 : SplickTheme.Spacing.xxs)
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
        .padding(.trailing, SplickTheme.Spacing.xxs)
        .padding(.top, isFilterPresented ? SplickTheme.Spacing.md : 0)
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
                HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                    Text(languageService.text(.expenseFilterPanelTitle))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)

                    Spacer(minLength: 0)

                    if viewModel.filters.hasNonDefaultListFilters {
                        Button(languageService.text(.expenseFilterClear)) {
                            captionQueryDraft = ""
                            friendQueryDraft = ""
                            friendSearchViewModel.reset(query: "")
                            viewModel.clearListFilters()
                        }
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                }

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
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
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
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))

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
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
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
                .splickCard()
        }
    }
}

private struct ExpenseRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                        .fill(SplickTheme.Colors.tertiaryBackground.opacity(0.7))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private struct ExpenseOverviewExpandedHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ExpenseOverviewCollapsedHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ExpenseOverviewAnimatedBody<Expanded: View, Collapsed: View>: View {
    let isExpanded: Bool
    @ViewBuilder var expanded: () -> Expanded
    @ViewBuilder var collapsed: () -> Collapsed

    @State private var expandedHeight: CGFloat = 0
    @State private var collapsedHeight: CGFloat = 0

    private var activeHeight: CGFloat? {
        let height = isExpanded ? expandedHeight : collapsedHeight
        return height > 0 ? height : nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            collapsed()
                .opacity(isExpanded ? 0 : 1)
                .scaleEffect(isExpanded ? 0.97 : 1, anchor: .top)
                .offset(y: isExpanded ? -8 : 0)
                .allowsHitTesting(!isExpanded)
                .accessibilityHidden(isExpanded)

            expanded()
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : 0.97, anchor: .top)
                .offset(y: isExpanded ? 0 : 8)
                .allowsHitTesting(isExpanded)
                .accessibilityHidden(!isExpanded)
        }
        .frame(height: activeHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .clipped()
        .background {
            VStack(spacing: 0) {
                expanded()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .measureExpenseOverviewHeight(key: ExpenseOverviewExpandedHeightKey.self) { expandedHeight = $0 }

                collapsed()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .measureExpenseOverviewHeight(key: ExpenseOverviewCollapsedHeightKey.self) { collapsedHeight = $0 }
            }
            .hidden()
            .accessibilityHidden(true)
        }
    }
}

private extension View {
    func measureExpenseOverviewHeight<Key: PreferenceKey>(
        key: Key.Type,
        onChange: @escaping (CGFloat) -> Void
    ) -> some View where Key.Value == CGFloat {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: key, value: proxy.size.height)
            }
        }
        .onPreferenceChange(key) { height in
            guard height > 0 else { return }
            onChange(height)
        }
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
