import SwiftUI
import DesignSystem
import Localization
import SplickDomain
import FeatureFriends

private typealias AlbumGroup = SplickDomain.Group

struct PhotoAlbumFilterBarView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: PhotoAlbumViewModel
    let currentUser: UserSummary?
    let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?

    @State private var captionQuery = ""
    @State private var isExpanded = false
    @State private var showPeoplePicker = false
    @State private var captionSearchTask: Task<Void, Never>?

    private var filters: PhotoAlbumFilters { viewModel.filters }

    private var expandAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.86)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            captionSearchField
            filterHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    kindChips
                    peopleChip
                }
                .animation(expandAnimation, value: selectedPeopleItems.map(\.id))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if filters.hasAnyFilter {
                clearButton
            }
        }
        .splickCard(padding: SplickTheme.Spacing.md)
        .sheet(isPresented: $showPeoplePicker) {
            PhotoAlbumPeoplePickerSheet(
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
            }
        }
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
    }

    private var captionSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            TextField(languageService.text(.feedAlbumSearchCaption), text: $captionQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: captionQuery) { newValue in
                    scheduleCaptionSearch(newValue)
                }
            if !captionQuery.isEmpty {
                Button {
                    captionQuery = ""
                    viewModel.setCaptionQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, 10)
        .background(
            SplickTheme.Colors.tertiaryBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var filterHeader: some View {
        Button {
            withAnimation(expandAnimation) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text(languageService.text(.feedFilterTitle))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var peoplePickerEnabled: Bool {
        currentUser != nil || fetchMyFriendsUseCase != nil || fetchMyGroupsUseCase != nil
    }

    private var selectedPeopleItems: [AlbumSelectedFilter] {
        filters.authors.map { .author($0) } + filters.groups.map { .group($0) }
    }

    @ViewBuilder
    private var peopleChip: some View {
        if selectedPeopleItems.isEmpty {
            emptyPeopleChip
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            selectedPeopleRow
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var emptyPeopleChip: some View {
        Button {
            showPeoplePicker = true
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "person.2")
                Text(languageService.text(.feedAlbumPickPeople))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SplickTheme.Colors.tertiaryBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(!peoplePickerEnabled)
        .opacity(peoplePickerEnabled ? 1 : 0.5)
    }

    private var selectedPeopleRow: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.md) {
                    ForEach(selectedPeopleItems) { item in
                        removableFilterAvatar(item)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 6)
                .animation(expandAnimation, value: selectedPeopleItems.map(\.id))
            }
            Button {
                showPeoplePicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().strokeBorder(
                            SplickTheme.Colors.primary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageService.text(.feedAlbumPickPeople))
            .disabled(!peoplePickerEnabled)
        }
    }

    private func removableFilterAvatar(_ item: AlbumSelectedFilter) -> some View {
        ZStack(alignment: .topTrailing) {
            AvatarView(
                imageURL: item.avatarURL,
                name: item.displayName,
                size: .compact,
                userId: item.userId
            )
            Button {
                removeSelectedFilter(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.black.opacity(0.72)))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
            .accessibilityLabel(
                languageService.format(.feedAlbumRemoveSelectedA11y, item.displayName)
            )
        }
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
            HStack(spacing: SplickTheme.Spacing.xs) {
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
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, 8)
                .foregroundStyle(isActive ? SplickTheme.Colors.primary : SplickTheme.Colors.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isActive
                                ? SplickTheme.Colors.primary.opacity(0.12)
                                : SplickTheme.Colors.tertiaryBackground
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var clearButton: some View {
        Button(languageService.text(.feedAlbumClearFilters)) {
            captionQuery = ""
            Task { await viewModel.clearFilters() }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(SplickTheme.Colors.primary)
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

private struct PhotoAlbumPeoplePickerSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            pickerContent
            .navigationTitle(languageService.text(.feedAlbumFilterPeople))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: languageService.text(.feedCreateSearchFriendsGroups))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonClose)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) {
                        onApply(draftAuthors, draftGroups)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .task {
                isLoading = true
                defer { isLoading = false }
                async let loadedFriends = loadFriends()
                async let loadedGroups = loadGroups()
                friends = await loadedFriends
                groups = await loadedGroups
            }
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if isLoading && currentUser == nil && friends.isEmpty && groups.isEmpty {
            ProgressView()
        } else if currentUser == nil && friends.isEmpty && groups.isEmpty {
            Text(languageService.text(.feedAlbumPeopleEmpty))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        } else if filteredCurrentUser == nil && filteredFriends.isEmpty && filteredGroups.isEmpty {
            Text(languageService.text(.feedFilterFriendsNotFound))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        } else {
            List {
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
            .listStyle(.plain)
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
                        .background(Circle().fill(selected ? SplickTheme.Colors.primary : Color.clear))
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
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selected ? SplickTheme.Colors.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 8)
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

    var userId: UUID? {
        switch self {
        case .author(let user): return user.id
        case .group: return nil
        }
    }
}
