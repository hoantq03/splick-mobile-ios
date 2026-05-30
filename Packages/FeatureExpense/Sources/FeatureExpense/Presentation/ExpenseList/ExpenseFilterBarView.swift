import SwiftUI
import DesignSystem
import Localization
import SplickDomain

private enum FilterMetrics {
    static let innerH: CGFloat = 8
    static let innerV: CGFloat = 5
    static let rowV: CGFloat = 4
    static let sectionSpacing: CGFloat = 5
    static let cardPadding: CGFloat = 8
}

struct ExpenseFilterBarView: View {
    @ObservedObject var viewModel: ExpenseListViewModel
    @ObservedObject var userSearchViewModel: ExpenseUserSearchViewModel
    @EnvironmentObject private var languageService: LanguageService

    @State private var captionQuery = ""
    @State private var userQuery = ""
    @State private var activeDatePicker: DatePickerField?
    @State private var captionSearchTask: Task<Void, Never>?

    private var filters: ExpenseListFilters { viewModel.filters }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            captionSearchSection
            moreFiltersHeader

            if filters.isAdvancedExpanded {
                advancedSection
            }
        }
        .animation(.easeOut(duration: 0.18), value: filters.isAdvancedExpanded)
        .splickCard(padding: FilterMetrics.cardPadding)
        .sheet(item: $activeDatePicker) { field in
            datePickerSheet(field: field)
        }
        .onAppear {
            if captionQuery.isEmpty {
                captionQuery = filters.captionQuery
            }
        }
        .onDisappear {
            captionSearchTask?.cancel()
        }
    }

    // MARK: - Caption search

    private var captionSearchSection: some View {
        compactTextField(
            placeholder: languageService.text(.expenseFilterSearchCaption),
            text: $captionQuery,
            icon: "magnifyingglass",
            onChange: { scheduleCaptionSearch(captionQuery) },
            onClear: {
                captionQuery = ""
                viewModel.setCaptionQuery("")
            }
        )
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

    private var moreFiltersHeader: some View {
        Button {
            viewModel.setAdvancedExpanded(!filters.isAdvancedExpanded)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text(languageService.text(.expenseFilterMore))
                    .font(.system(size: 11, weight: .semibold))
                if filters.hasAdvancedFilters {
                    Circle()
                        .fill(SplickTheme.Colors.primaryGradientStart)
                        .frame(width: 5, height: 5)
                }
                Spacer(minLength: 0)
                Image(systemName: filters.isAdvancedExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .padding(.horizontal, FilterMetrics.innerH)
            .padding(.vertical, FilterMetrics.rowV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: FilterMetrics.sectionSpacing) {
            statusSection
            userFilterSection
            dateFilterSection

            if filters.hasAdvancedFilters {
                Button(languageService.text(.expenseFilterClear)) {
                    clearAdvancedFilters()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
        }
        .padding(.top, FilterMetrics.rowV)
        .transition(.opacity)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            filterLabel(languageService.text(.expenseFilterStatus))

            Picker(languageService.text(.expenseFilterStatus), selection: Binding(
                get: { filters.debtStatus },
                set: { viewModel.setDebtStatus($0) }
            )) {
                ForEach(ExpenseDebtFilter.allCases) { status in
                    Text(status.title(using: languageService)).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .scaleEffect(0.92)
            .frame(maxWidth: .infinity)
        }
    }

    private var userFilterSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            filterLabel(languageService.text(.expenseFilterUser))

            if let user = filters.selectedUser {
                selectedUserChip(user)
            } else {
                compactTextField(
                    placeholder: languageService.text(.expenseFilterSearchUser),
                    text: $userQuery,
                    icon: "person.fill",
                    onChange: {
                        userSearchViewModel.reset(query: userQuery)
                    }
                )

                if !userQuery.isEmpty {
                    userResultsList
                }
            }
        }
    }

    private func selectedUserChip(_ user: UserSummary) -> some View {
        HStack(spacing: 6) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .small)
                .scaleEffect(0.72)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 0) {
                Text(user.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("@\(user.username)")
                    .font(.system(size: 10))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button { clearUserSelection() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FilterMetrics.innerH)
        .padding(.vertical, FilterMetrics.innerV)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var userResultsList: some View {
        Group {
            if userSearchViewModel.isLoading && userSearchViewModel.users.isEmpty {
                SplickSpinner(size: .small)
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
            } else if userSearchViewModel.users.isEmpty {
                Text(languageService.text(.expenseFilterNoUsers))
                    .font(.system(size: 10))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(userSearchViewModel.users) { user in
                        Button {
                            viewModel.setSelectedUser(user)
                            userQuery = ""
                            userSearchViewModel.reset(query: "")
                        } label: {
                            HStack(spacing: 6) {
                                AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .small)
                                    .scaleEffect(0.68)
                                    .frame(width: 22, height: 22)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(user.displayName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Text("@\(user.username)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(height: 30)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task { await userSearchViewModel.loadMoreIfNeeded(current: user) }
                        }
                        if user.id != userSearchViewModel.users.last?.id {
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 92)
            }
        }
    }

    private var dateFilterSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            filterLabel(languageService.text(.expenseFilterDateRange))
            dateRow(field: .from, label: languageService.text(.expenseFilterFrom), date: filters.dateFrom)
            dateRow(field: .to, label: languageService.text(.expenseFilterTo), date: filters.dateTo)
        }
    }

    private func dateRow(field: DatePickerField, label: String, date: Date?) -> some View {
        Button {
            activeDatePicker = field
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 14)

                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                Spacer(minLength: 0)

                Text(dateLabel(date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        date == nil ? SplickTheme.Colors.textTertiary : SplickTheme.Colors.textPrimary
                    )
                    .lineLimit(1)

                if date != nil {
                    Button { setDate(nil, for: field) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, FilterMetrics.innerH)
            .padding(.vertical, FilterMetrics.innerV)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact field helper

    private func compactTextField(
        placeholder: String,
        text: Binding<String>,
        icon: String,
        onChange: @escaping () -> Void = {},
        onClear: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: 14)

            TextField(placeholder, text: text)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: text.wrappedValue) { _ in onChange() }

            if onClear != nil, !text.wrappedValue.isEmpty {
                Button(action: { onClear?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FilterMetrics.innerH)
        .padding(.vertical, FilterMetrics.innerV)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func filterLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(SplickTheme.Colors.textTertiary)
    }

    private func datePickerSheet(field: DatePickerField) -> some View {
        let title = field.title(using: languageService)
        return NavigationStack {
            VStack {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { currentDate(for: field) ?? Date() },
                        set: { setDate($0, for: field) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonClear)) {
                        setDate(nil, for: field)
                        activeDatePicker = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { activeDatePicker = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return languageService.text(.expenseFilterAnyTime) }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func currentDate(for field: DatePickerField) -> Date? {
        switch field {
        case .from: return filters.dateFrom
        case .to: return filters.dateTo
        }
    }

    private func setDate(_ date: Date?, for field: DatePickerField) {
        switch field {
        case .from: viewModel.setDateFrom(date)
        case .to: viewModel.setDateTo(date)
        }
    }

    private func clearUserSelection() {
        viewModel.setSelectedUser(nil)
        userQuery = ""
        userSearchViewModel.reset(query: "")
    }

    private func clearAdvancedFilters() {
        viewModel.clearAdvancedFilters()
        userQuery = ""
        userSearchViewModel.reset(query: "")
    }
}

private enum DatePickerField: String, Identifiable {
    case from
    case to

    var id: String { rawValue }

    @MainActor
    func title(using languageService: LanguageService) -> String {
        switch self {
        case .from: return languageService.text(.expenseFilterFromDate)
        case .to: return languageService.text(.expenseFilterToDate)
        }
    }
}
