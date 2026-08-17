import SwiftUI
import DesignSystem
import Localization
import SplickDomain
import FeatureFriends

struct PhotoAlbumFilterBarView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: PhotoAlbumViewModel
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
                peopleChip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if filters.hasAnyFilter {
                clearButton
            }
        }
        .splickCard(padding: SplickTheme.Spacing.md)
        .sheet(isPresented: $showPeoplePicker) {
            PhotoAlbumPeoplePickerSheet(
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

    private var peopleChip: some View {
        let names = filters.authors.map(\.displayName) + filters.groups.map(\.name)
        let title: String = {
            if names.isEmpty {
                return languageService.text(.feedAlbumPickPeople)
            }
            if names.count == 1 {
                return names[0]
            }
            return languageService.format(.feedAlbumSelectedCount, names.count)
        }()
        let isActive = !filters.authors.isEmpty || !filters.groups.isEmpty
        let enabled = fetchMyFriendsUseCase != nil || fetchMyGroupsUseCase != nil

        return Button {
            showPeoplePicker = true
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "person.2")
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isActive ? SplickTheme.Colors.primary : SplickTheme.Colors.textPrimary)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, 10)
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
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
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

    let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?
    let selectedAuthors: [UserSummary]
    let selectedGroups: [Group]
    let onApply: ([UserSummary], [Group]) -> Void

    @State private var friends: [UserSummary] = []
    @State private var groups: [Group] = []
    @State private var draftAuthors: [UserSummary]
    @State private var draftGroups: [Group]
    @State private var searchQuery = ""
    @State private var isLoading = true

    init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?,
        selectedAuthors: [UserSummary],
        selectedGroups: [Group],
        onApply: @escaping ([UserSummary], [Group]) -> Void
    ) {
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.selectedAuthors = selectedAuthors
        self.selectedGroups = selectedGroups
        self.onApply = onApply
        _draftAuthors = State(initialValue: selectedAuthors)
        _draftGroups = State(initialValue: selectedGroups)
    }

    private var filteredFriends: [UserSummary] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return friends }
        return friends.filter {
            $0.displayName.lowercased().contains(query)
                || $0.username.lowercased().contains(query)
        }
    }

    private var filteredGroups: [Group] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return groups }
        return groups.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if isLoading {
                    ProgressView()
                } else if friends.isEmpty && groups.isEmpty {
                    Text(languageService.text(.feedAlbumPeopleEmpty))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                } else if filteredFriends.isEmpty && filteredGroups.isEmpty {
                    Text(languageService.text(.feedFilterFriendsNotFound))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                } else {
                    List {
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

    private func toggleGroup(_ group: Group) {
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

    private func loadGroups() async -> [Group] {
        guard let fetchMyGroupsUseCase else { return [] }
        return (try? await fetchMyGroupsUseCase.execute()) ?? []
    }
}
