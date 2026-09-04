import SwiftUI
import DesignSystem
import Localization
import SplickDomain
import FeatureFriends

struct ExpensePeoplePickerSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    let currentUser: UserSummary?
    let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?
    let selectedUsers: [UserSummary]
    let selectedGroups: [SplickDomain.Group]
    let onApply: ([UserSummary], [SplickDomain.Group]) -> Void

    @State private var friends: [UserSummary] = []
    @State private var groups: [SplickDomain.Group] = []
    @State private var draftUsers: [UserSummary]
    @State private var draftGroups: [SplickDomain.Group]
    @State private var searchQuery = ""
    @State private var isLoading = true

    init(
        currentUser: UserSummary?,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?,
        selectedUsers: [UserSummary],
        selectedGroups: [SplickDomain.Group],
        onApply: @escaping ([UserSummary], [SplickDomain.Group]) -> Void
    ) {
        self.currentUser = currentUser
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.selectedUsers = selectedUsers
        self.selectedGroups = selectedGroups
        self.onApply = onApply
        _draftUsers = State(initialValue: selectedUsers)
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

    private var filteredGroups: [SplickDomain.Group] {
        guard !normalizedQuery.isEmpty else { return groups }
        return groups.filter { $0.name.lowercased().contains(normalizedQuery) }
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
                            onApply(draftUsers, draftGroups)
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
        if isLoading {
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
                        selected: draftUsers.contains(where: { $0.id == me.id })
                    ) {
                        toggleUser(me)
                    }
                }
                ForEach(filteredFriends) { friend in
                    peopleRow(
                        title: friend.displayName,
                        subtitle: "@\(friend.username)",
                        avatarURL: friend.avatarURL,
                        isGroup: false,
                        selected: draftUsers.contains(where: { $0.id == friend.id })
                    ) {
                        toggleUser(friend)
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

    private func toggleUser(_ user: UserSummary) {
        if let index = draftUsers.firstIndex(where: { $0.id == user.id }) {
            draftUsers.remove(at: index)
        } else {
            draftUsers.append(user)
        }
    }

    private func toggleGroup(_ group: SplickDomain.Group) {
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

    private func loadGroups() async -> [SplickDomain.Group] {
        guard let fetchMyGroupsUseCase else { return [] }
        return (try? await fetchMyGroupsUseCase.execute()) ?? []
    }
}
