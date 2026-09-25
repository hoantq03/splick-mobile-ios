import SwiftUI
import DesignSystem
import Localization
import Networking
import SplickDomain
import FeatureFriends

private enum AlbumFilterMetrics {
    static let innerH: CGFloat = 10
    static let innerV: CGFloat = 8
    static let rowV: CGFloat = 6
    static let sectionSpacing: CGFloat = 8
    static let cardPadding: CGFloat = SplickTheme.Spacing.sm
    static let fieldRadius: CGFloat = SplickTheme.CornerRadius.inset
}

enum AlbumFilterMotion {
    static let bounce = Animation.spring(response: 0.42, dampingFraction: 0.58)
    static let collapsedScale: CGFloat = 0.22
    static let filterOffset: CGFloat = 48
    static let peopleOffsetFallback: CGFloat = 102
}

private typealias AlbumGroup = SplickDomain.Group

struct PhotoAlbumFilterBarView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: PhotoAlbumViewModel
    let currentUser: UserSummary?
    let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?

    @Binding var showFilterPopup: Bool
    @Binding var showPeoplePane: Bool

    @State private var captionQuery = ""
    @FocusState private var isCaptionFocused: Bool
    @State private var filterBarWidth: CGFloat = 0
    @State private var captionSearchTask: Task<Void, Never>?
    @State private var filterHosted = false
    @State private var peopleHosted = false
    @State private var peopleAnchorY: CGFloat = AlbumFilterMotion.peopleOffsetFallback

    private var filters: PhotoAlbumFilters { viewModel.filters }

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
        HStack(spacing: SplickTheme.Spacing.sm) {
            captionSearchField
            filterButton
        }
        .coordinateSpace(name: "albumFilterBar")
        .overlay(alignment: .topTrailing) {
            filterMenuOverlays
        }
        .onPreferenceChange(AlbumPeopleAnchorYKey.self) { value in
            if value > AlbumFilterMotion.filterOffset {
                peopleAnchorY = value
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: AlbumFilterBarWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(AlbumFilterBarWidthKey.self) { filterBarWidth = $0 }
        .onAppear {
            if captionQuery.isEmpty {
                captionQuery = filters.captionQuery
            }
        }
        .onChange(of: viewModel.filters.captionQuery) { newValue in
            if captionQuery != newValue {
                captionQuery = newValue
            }
        }
        .onDisappear {
            captionSearchTask?.cancel()
        }
        .onChange(of: showFilterPopup) { shown in
            hostPane(shown: shown, hosted: $filterHosted, stillExpanded: { showFilterPopup })
        }
        .onChange(of: showPeoplePane) { shown in
            hostPane(shown: shown, hosted: $peopleHosted, stillExpanded: { showPeoplePane })
        }
        if isCaptionFocused,
           captionQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let history = viewModel.searchHistory {
            RecentSearchesSection(
                items: history.items,
                languageService: languageService,
                onSelect: { item in
                    captionQuery = item.query
                    viewModel.setCaptionQuery(item.query)
                },
                onDelete: { history.delete($0) },
                onClearAll: { history.clear() }
            )
        }
        }
    }

    private var captionSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            TextField(languageService.text(.feedAlbumSearchCaption), text: $captionQuery)
                .font(SplickTheme.Typography.callout)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isCaptionFocused)
                .onChange(of: captionQuery) { newValue in
                    scheduleCaptionSearch(newValue)
                }
                .onChange(of: isCaptionFocused) { focused in
                    if focused && captionQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Task { await viewModel.searchHistory?.refresh() }
                    }
                }
            if !captionQuery.isEmpty {
                Button {
                    captionQuery = ""
                    viewModel.setCaptionQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }

    private var filterButton: some View {
        Button {
            withAnimation(AlbumFilterMotion.bounce) {
                if showPeoplePane {
                    showPeoplePane = false
                } else {
                    showFilterPopup.toggle()
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        filters.hasAdvancedFilters
                            ? SplickTheme.Colors.primaryGradientStart
                            : SplickTheme.Colors.textSecondary
                    )
                    .frame(width: 40, height: 40)
                    .background(SplickTheme.Colors.secondaryBackground, in: Circle())
                if filters.hasAdvancedFilters {
                    Circle()
                        .fill(SplickTheme.Colors.primaryGradientStart)
                        .frame(width: 8, height: 8)
                        .offset(x: -2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.feedFilterTitle))
    }

    @ViewBuilder
    private var filterMenuOverlays: some View {
        if filterHosted {
            filterPopoverContent
                .albumFilterCardStyle(elevated: false)
                .albumFilterBounce(expanded: showFilterPopup)
                .offset(y: AlbumFilterMotion.filterOffset)
                .allowsHitTesting(showFilterPopup)
                .zIndex(1)
        }
        if peopleHosted {
            peoplePopoverContent
                .albumFilterCardStyle(elevated: true)
                .albumFilterBounce(expanded: showPeoplePane)
                .offset(y: peopleAnchorY)
                .allowsHitTesting(showPeoplePane)
                .zIndex(2)
        }
    }

    private var filterPopoverContent: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            kindChips
            peopleChip
            if filters.hasAdvancedFilters {
                Button(languageService.text(.feedAlbumClearFilters)) {
                    captionQuery = ""
                    Task { await viewModel.clearFilters() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
        }
        .padding(SplickTheme.Spacing.md)
        .frame(width: popoverWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var popoverWidth: CGFloat {
        filterBarWidth > 0 ? filterBarWidth : max(280, UIScreen.main.bounds.width - SplickTheme.Spacing.md * 2)
    }

    private var peoplePickerEnabled: Bool {
        currentUser != nil || fetchMyFriendsUseCase != nil || fetchMyGroupsUseCase != nil
    }

    private func presentPeoplePicker() {
        withAnimation(AlbumFilterMotion.bounce) {
            showPeoplePane = true
        }
    }

    private func dismissPeoplePane() {
        withAnimation(AlbumFilterMotion.bounce) {
            showPeoplePane = false
        }
    }

    private func hostPane(shown: Bool, hosted: Binding<Bool>, stillExpanded: @escaping () -> Bool) {
        if shown {
            hosted.wrappedValue = true
            return
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            if !stillExpanded() {
                hosted.wrappedValue = false
            }
        }
    }

    private var peoplePopoverContent: some View {
        PhotoAlbumPeoplePickerPane(
            currentUser: currentUser,
            fetchMyFriendsUseCase: fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: fetchMyGroupsUseCase,
            selectedAuthors: filters.authors,
            selectedGroups: filters.groups
        ) { authors, groups in
            Task {
                var updated = filters
                updated.authors = authors
                updated.groups = groups
                await viewModel.applyFilters(updated)
            }
            dismissPeoplePane()
        }
        .frame(width: popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var selectedPeopleItems: [AlbumSelectedFilter] {
        filters.authors.map { .author($0) } + filters.groups.map { .group($0) }
    }

    @ViewBuilder
    private var peopleChip: some View {
        VStack(alignment: .leading, spacing: 8) {
            emptyPeopleChip
            if !selectedPeopleItems.isEmpty {
                selectedPeopleRow
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: AlbumPeopleAnchorYKey.self,
                    value: geo.frame(in: .named("albumFilterBar")).minY
                )
            }
        )
    }

    private var emptyPeopleChip: some View {
        Button {
            presentPeoplePicker()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(width: 14)
                Text(languageService.text(.feedAlbumPickPeople))
                    .font(.system(size: 12))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .padding(.horizontal, AlbumFilterMetrics.innerH)
            .padding(.vertical, AlbumFilterMetrics.innerV)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AlbumFilterMetrics.fieldRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!peoplePickerEnabled)
        .opacity(peoplePickerEnabled ? 1 : 0.5)
    }

    private var selectedPeopleRow: some View {
        AlbumChipFlowLayout(spacing: 6) {
            ForEach(selectedPeopleItems) { item in
                selectedPeopleChip(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectedPeopleChip(_ item: AlbumSelectedFilter) -> some View {
        HStack(spacing: 6) {
            AvatarView(
                imageURL: item.avatarURL,
                name: item.displayName,
                size: .small,
                userId: item.userId
            )
            .scaleEffect(0.72)
            .frame(width: 24, height: 24)

            Image(systemName: item.isGroup ? "person.3" : "person.2")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Text(item.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)

            Button {
                removeSelectedFilter(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                languageService.format(.feedAlbumRemoveSelectedA11y, item.displayName)
            )
        }
        .padding(.horizontal, AlbumFilterMetrics.innerH)
        .padding(.vertical, 6)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AlbumFilterMetrics.fieldRadius, style: .continuous))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.72).combined(with: .opacity),
            removal: .scale(scale: 0.72).combined(with: .opacity)
        ))
    }

    private func removeSelectedFilter(_ item: AlbumSelectedFilter) {
        var updated = filters
        switch item {
        case .author(let user):
            updated.authors.removeAll { $0.id == user.id }
        case .group(let group):
            updated.groups.removeAll { $0.id == group.id }
        }
        Task { await viewModel.applyFilters(updated) }
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                kindChip(title: languageService.text(.feedAlbumKindAll), kind: nil)
                kindChip(title: languageService.text(.feedAlbumKindMoment), kind: .checkIn)
                kindChip(title: languageService.text(.feedAlbumKindBill), kind: .shareBill)
            }
        }
    }

    private func kindChip(title: String, kind: PostFeedKind?) -> some View {
        let isActive = filters.feedKind == kind
        return Button {
            Task {
                var updated = filters
                updated.feedKind = kind
                await viewModel.applyFilters(updated)
            }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(
                    isActive
                        ? SplickTheme.Colors.primaryGradientStart
                        : SplickTheme.Colors.textSecondary
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            isActive
                                ? SplickTheme.Colors.primaryGradientStart.opacity(0.14)
                                : SplickTheme.Colors.secondaryBackground
                        )
                }
                .animation(.easeInOut(duration: 0.18), value: isActive)
        }
        .buttonStyle(.plain)
    }

    private func scheduleCaptionSearch(_ query: String) {
        captionSearchTask?.cancel()
        captionSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.setCaptionQuery(query)
            }
        }
    }
}

private struct AlbumFilterBarWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AlbumPeopleAnchorYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AlbumChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = layout(proposal: ProposedViewSize(bounds.size), subviews: subviews).frames
        for (index, subview) in subviews.enumerated() {
            let frame = frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let unconstrained = subview.sizeThatFits(.unspecified)
            let itemWidth = min(unconstrained.width, maxWidth)
            let itemHeight = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: unconstrained.height)).height
            if x > 0, x + itemWidth > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: itemWidth, height: itemHeight))
            rowHeight = max(rowHeight, itemHeight)
            x += itemWidth + spacing
            usedWidth = max(usedWidth, x - spacing)
        }

        let width = maxWidth.isFinite ? maxWidth : usedWidth
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}

private struct AlbumFilterBounceModifier: ViewModifier {
    let expanded: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : AlbumFilterMotion.collapsedScale, anchor: .topTrailing)
            .opacity(shown ? 1 : 0)
            .onAppear {
                shown = false
                if expanded {
                    withAnimation(AlbumFilterMotion.bounce) {
                        shown = true
                    }
                }
            }
            .onChange(of: expanded) { isExpanded in
                withAnimation(AlbumFilterMotion.bounce) {
                    shown = isExpanded
                }
            }
    }
}

private struct AlbumFilterCardStyle: ViewModifier {
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SplickTheme.Colors.secondaryBackground)
                    .shadow(
                        color: .black.opacity(elevated ? 0.22 : 0.12),
                        radius: elevated ? 22 : 14,
                        y: elevated ? 10 : 6
                    )
            )
            .frame(width: nil, alignment: .trailing)
    }
}

private extension View {
    func albumFilterBounce(expanded: Bool) -> some View {
        modifier(AlbumFilterBounceModifier(expanded: expanded))
    }

    func albumFilterCardStyle(elevated: Bool) -> some View {
        modifier(AlbumFilterCardStyle(elevated: elevated))
    }
}

private struct PhotoAlbumPeoplePickerPane: View {
    @EnvironmentObject private var languageService: LanguageService

    let currentUser: UserSummary?
    let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?
    let selectedAuthors: [UserSummary]
    let selectedGroups: [AlbumGroup]
    let onApply: ([UserSummary], [AlbumGroup]) -> Void

    @State private var friends: [UserSummary] = []
    @State private var groups: [AlbumGroup] = []
    @State private var draftAuthors: [UserSummary]
    @State private var draftGroups: [AlbumGroup]
    @State private var searchQuery = ""
    @State private var isLoading = true

    init(
        currentUser: UserSummary?,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?,
        selectedAuthors: [UserSummary],
        selectedGroups: [AlbumGroup],
        onApply: @escaping ([UserSummary], [AlbumGroup]) -> Void
    ) {
        self.currentUser = currentUser
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.selectedAuthors = selectedAuthors
        self.selectedGroups = selectedGroups
        self.onApply = onApply
        _draftAuthors = State(initialValue: selectedAuthors)
        _draftGroups = State(initialValue: selectedGroups)
    }

    private var normalizedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredCurrentUser: UserSummary? {
        guard let currentUser else { return nil }
        guard !normalizedQuery.isEmpty else { return currentUser }
        let meLabel = languageService.text(.commonMe).lowercased()
        if meLabel.contains(normalizedQuery)
            || currentUser.displayName.lowercased().contains(normalizedQuery)
            || currentUser.username.lowercased().contains(normalizedQuery) {
            return currentUser
        }
        return nil
    }

    private var filteredFriends: [UserSummary] {
        let others = friends.filter { $0.id != currentUser?.id }
        guard !normalizedQuery.isEmpty else { return others }
        return others.filter {
            $0.displayName.lowercased().contains(normalizedQuery)
                || $0.username.lowercased().contains(normalizedQuery)
        }
    }

    private var filteredGroups: [AlbumGroup] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return groups }
        return groups.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Text(languageService.text(.feedAlbumFilterPeople))
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(languageService.text(.commonDone)) {
                    onApply(draftAuthors, draftGroups)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .buttonStyle(.plain)
            }
            peopleSearchField
            pickerContent
        }
        .padding(SplickTheme.Spacing.md)
        .task {
            isLoading = true
            defer { isLoading = false }
            async let loadedFriends = loadFriends()
            async let loadedGroups = loadGroups()
            friends = await loadedFriends
            groups = await loadedGroups
        }
    }

    private var peopleSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            TextField(languageService.text(.feedCreateSearchFriendsGroups), text: $searchQuery)
                .font(SplickTheme.Typography.caption)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, AlbumFilterMetrics.innerH)
        .padding(.vertical, 8)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AlbumFilterMetrics.fieldRadius, style: .continuous))
    }

    @ViewBuilder
    private var pickerContent: some View {
        if isLoading && currentUser == nil && friends.isEmpty && groups.isEmpty {
            SplickSpinner(size: .medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.md)
        } else if currentUser == nil && friends.isEmpty && groups.isEmpty {
            Text(languageService.text(.feedAlbumPeopleEmpty))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.vertical, SplickTheme.Spacing.sm)
        } else if filteredCurrentUser == nil && filteredFriends.isEmpty && filteredGroups.isEmpty {
            Text(languageService.text(.feedFilterFriendsNotFound))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.vertical, SplickTheme.Spacing.sm)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if let me = filteredCurrentUser {
                        peopleRow(
                            title: languageService.text(.commonMe),
                            subtitle: "@\(me.username)",
                            avatarURL: me.avatarURL,
                            isGroup: false,
                            selected: draftAuthors.contains(where: { $0.id == me.id })
                        ) {
                            toggleAuthor(me)
                        }
                    }
                    ForEach(filteredFriends) { friend in
                        peopleRow(
                            title: friend.displayName,
                            subtitle: "@\(friend.username)",
                            avatarURL: friend.avatarURL,
                            isGroup: false,
                            selected: draftAuthors.contains(where: { $0.id == friend.id })
                        ) {
                            toggleAuthor(friend)
                        }
                    }
                    ForEach(filteredGroups) { group in
                        peopleRow(
                            title: group.name,
                            subtitle: languageService.text(.feedFilterByGroups),
                            avatarURL: group.avatarURL,
                            isGroup: true,
                            selected: draftGroups.contains(where: { $0.id == group.id })
                        ) {
                            toggleGroup(group)
                        }
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

    private func peopleRow(
        title: String,
        subtitle: String,
        avatarURL: URL?,
        isGroup: Bool,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AvatarView(imageURL: avatarURL, name: title, size: .small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: isGroup ? "person.3" : "person")
                            .font(.system(size: 10, weight: .semibold))
                        Text(subtitle)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? Color.clear : SplickTheme.Colors.textTertiary.opacity(0.5), lineWidth: 1.5)
                        .background(Circle().fill(selected ? SplickTheme.Colors.primaryGradientStart : Color.clear))
                        .frame(width: 22, height: 22)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? SplickTheme.Colors.primaryGradientStart.opacity(0.08) : Color.clear)
        )
    }

    private func toggleAuthor(_ friend: UserSummary) {
        if let index = draftAuthors.firstIndex(where: { $0.id == friend.id }) {
            draftAuthors.remove(at: index)
        } else {
            draftAuthors.append(friend)
        }
    }

    private func toggleGroup(_ group: AlbumGroup) {
        if let index = draftGroups.firstIndex(where: { $0.id == group.id }) {
            draftGroups.remove(at: index)
        } else {
            draftGroups.append(group)
        }
    }

    private func loadFriends() async -> [UserSummary] {
        guard let fetchMyFriendsUseCase else { return [] }
        return (try? await fetchMyFriendsUseCase.execute()) ?? []
    }

    private func loadGroups() async -> [AlbumGroup] {
        guard let fetchMyGroupsUseCase else { return [] }
        return (try? await fetchMyGroupsUseCase.execute()) ?? []
    }
}

private enum AlbumSelectedFilter: Identifiable, Equatable {
    case author(UserSummary)
    case group(AlbumGroup)

    var id: String {
        switch self {
        case .author(let user): return "u-\(user.id.uuidString)"
        case .group(let group): return "g-\(group.id.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case .author(let user): return user.displayName
        case .group(let group): return group.name
        }
    }

    var avatarURL: URL? {
        switch self {
        case .author(let user): return user.avatarURL
        case .group(let group): return group.avatarURL
        }
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }

    var userId: UUID? {
        switch self {
        case .author(let user): return user.id
        case .group: return nil
        }
    }
}
