import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

public struct ExpenseListView: View {
    @StateObject private var viewModel: ExpenseListViewModel
    @State private var isOverviewExpanded = false
    @State private var showFilterPanel = false
    @State private var filterRevealOrigin: CGPoint = .zero
    @State private var captionQueryDraft = ""
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.openPostCaptureFlow) private var openPostCaptureFlow
    @Environment(\.openLinkedPost) private var openLinkedPost
    private let currentUserId: UUID?

    private let overviewToggleAnimation = Animation.spring(response: 0.48, dampingFraction: 0.86)
    private let listFilterAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86)

    public init(
        viewModel: @autoclosure @escaping () -> ExpenseListViewModel,
        currentUserId: UUID? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.currentUserId = currentUserId
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
    }

    private var expenseContent: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.md) {
                    debtSummarySection

                    expenseRecordsSection
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
            .tabBarHideOnScroll()

            if showFilterPanel {
                ExpenseFilterRevealOverlay(
                    isPresented: $showFilterPanel,
                    origin: filterRevealOrigin
                ) {
                    ExpenseListFilterPanel(
                        viewModel: viewModel,
                        captionQueryDraft: $captionQueryDraft,
                        languageService: languageService
                    )
                }
                .zIndex(1)
            }
        }
        .onAppear {
            if captionQueryDraft.isEmpty {
                captionQueryDraft = viewModel.filters.captionQuery
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
                filterAccessibilityLabel: languageService.text(.expenseFilterOpenAccessibility),
                onFilterTap: { frame in
                    filterRevealOrigin = CGPoint(x: frame.midX, y: frame.midY)
                    withAnimation(ExpenseFilterRevealMotion.expand) {
                        showFilterPanel = true
                    }
                }
            )

            content()
        }
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
                    layout: .grouped
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
                        .padding(.leading, 92)
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
        Button(action: onTap) {
            HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                creatorColumn

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                    Text(formatAmount(expense.totalAmount))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(formatSignedAmount(userCashFlow))
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(amountColor(for: userCashFlow.direction))
                        .lineLimit(1)

                    Text(expense.createdAt.expenseListRelativeString)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(ageUrgency.color)
                        .lineLimit(1)
                        .padding(.horizontal, SplickTheme.Spacing.xs)
                        .padding(.vertical, SplickTheme.Spacing.xxxs)
                        .background {
                            Capsule()
                                .fill(ageUrgency.color.opacity(0.12))
                        }
                }

                Spacer(minLength: SplickTheme.Spacing.xs)

                paymentStatusIcon
            }
            .contentShape(Rectangle())
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .modifier(ExpenseRowChromeModifier(layout: layout))
        }
        .buttonStyle(ExpenseRowPressStyle())
        .disabled(!isLinkedToPost)
        .opacity(isLinkedToPost ? 1 : 0.55)
    }

    private var creatorColumn: some View {
        VStack(spacing: SplickTheme.Spacing.xxxs) {
            AvatarView(
                imageURL: expense.paidBy.avatarURL,
                name: expense.paidBy.displayName,
                size: .small,
                userId: expense.paidBy.id
            )
            .clipShape(Circle())
            .frame(width: 44, height: 44)

            Text(languageService.text(.expenseRowCreatorLabel))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 56)
    }

    @ViewBuilder
    private var paymentStatusIcon: some View {
        Group {
            if isPaidForCurrentUser {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.success)
                    .accessibilityLabel(languageService.text(.expenseRowPaidAccessibility))
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.error)
                    .accessibilityLabel(languageService.text(.expenseRowUnpaidAccessibility))
            }
        }
        .frame(width: 36, height: 36)
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

    private func formatSignedAmount(_ cashFlow: ExpenseUserCashFlow) -> String {
        let formatted = formatAmount(abs(cashFlow.amount))
        switch cashFlow.direction {
        case .receiving:
            return "+\(formatted)"
        case .paying:
            return "-\(formatted)"
        case .neutral:
            return formatted
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

private struct ExpenseListSectionHeader: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let accent: Color
    var showsFilterBadge: Bool = false
    let filterAccessibilityLabel: String
    let onFilterTap: (CGRect) -> Void

    @State private var filterButtonFrame: CGRect = .zero

    var body: some View {
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

            Button {
                onFilterTap(filterButtonFrame)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            showsFilterBadge
                                ? accent
                                : SplickTheme.Colors.textSecondary
                        )
                        .frame(width: 30, height: 30)
                        .background {
                            Circle()
                                .fill(
                                    showsFilterBadge
                                        ? accent.opacity(0.14)
                                        : SplickTheme.Colors.secondaryBackground
                                )
                        }

                    if showsFilterBadge {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                            .offset(x: 2, y: -1)
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ExpenseFilterButtonFrameKey.self,
                            value: proxy.frame(in: .global)
                        )
                    }
                }
                .onPreferenceChange(ExpenseFilterButtonFrameKey.self) { filterButtonFrame = $0 }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(filterAccessibilityLabel)
        }
        .padding(.horizontal, SplickTheme.Spacing.xxs)
    }
}

private struct ExpenseFilterButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private enum ExpenseFilterRevealMotion {
    static let expand = Animation.spring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.08)
    static let collapse = Animation.spring(response: 0.38, dampingFraction: 0.92, blendDuration: 0.06)
}

private struct ExpenseFilterRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let origin: CGPoint
    @ViewBuilder var content: () -> Content

    @State private var revealProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(340, proxy.size.width - SplickTheme.Spacing.xl)
            let cardOriginY = min(origin.y + 18, proxy.size.height * 0.22)
            let trailingInset = max(SplickTheme.Spacing.md, proxy.size.width - origin.x - 12)
            let coverRadius = hypot(cardWidth, 320)

            ZStack(alignment: .topTrailing) {
                Color.black.opacity(Double(revealProgress) * 0.18)
                    .ignoresSafeArea()
                    .onTapGesture { dismissAnimated() }

                content()
                    .frame(width: cardWidth, alignment: .leading)
                    .padding(.top, cardOriginY)
                    .padding(.trailing, trailingInset)
                    .mask {
                        Circle()
                            .frame(
                                width: max(coverRadius * 2 * revealProgress, 1),
                                height: max(coverRadius * 2 * revealProgress, 1)
                            )
                            .position(origin)
                    }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(ExpenseFilterRevealMotion.expand) {
                revealProgress = 1
            }
        }
    }

    private func dismissAnimated() {
        guard isPresented else { return }
        withAnimation(ExpenseFilterRevealMotion.collapse) {
            revealProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            isPresented = false
        }
    }
}

private struct ExpenseListFilterPanel: View {
    @ObservedObject var viewModel: ExpenseListViewModel
    @Binding var captionQueryDraft: String
    let languageService: LanguageService

    @State private var captionSearchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            HStack {
                Text(languageService.text(.expenseFilterPanelTitle))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Spacer(minLength: 0)
                if viewModel.filters.hasNonDefaultListFilters {
                    Button(languageService.text(.expenseFilterClear)) {
                        captionQueryDraft = ""
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

            if !viewModel.filterParticipantUsers.isEmpty {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    filterSectionLabel(languageService.text(.expenseFilterUser))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SplickTheme.Spacing.xs) {
                            ForEach(viewModel.filterParticipantUsers) { user in
                                userChip(user)
                            }
                        }
                    }
                }
            }
        }
        .padding(SplickTheme.Spacing.md)
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
                        .strokeBorder(SplickTheme.Colors.primaryGradientStart.opacity(0.1), lineWidth: 1)
                }
        }
        .onDisappear {
            captionSearchTask?.cancel()
        }
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
