import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

private enum ComposeMetrics {
    static let selectedTileWidth: CGFloat = 72
    static let selectedNameWidth: CGFloat = 64
}

public struct NewMessageComposeView: View {
    @ObservedObject private var viewModel: NewMessageComposeViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isMessageFocused: Bool

    let onSent: (Conversation) -> Void

    public init(
        viewModel: NewMessageComposeViewModel,
        onSent: @escaping (Conversation) -> Void
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onSent = onSent
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                composeSearchBar
                selectedRecipientsStrip
                directoryContent
                Divider()
                composeInputBar
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.messagingNewConversation))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
            .task {
                await viewModel.loadDirectoryIfNeeded()
            }
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
        }
    }

    private var composeSearchBar: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(languageService.text(.messagingComposeSearchPlaceholder), text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
    }

    @ViewBuilder
    private var selectedRecipientsStrip: some View {
        if viewModel.hasRecipients {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                    if let group = viewModel.selectedGroup {
                        selectedGroupTile(group)
                    }
                    ForEach(viewModel.selectedUsers) { user in
                        selectedUserTile(user)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private var directoryContent: some View {
        if viewModel.isLoadingDirectory {
            LoadingView(message: languageService.text(.messagingLoading))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                    if !viewModel.filteredRemoteUsers.isEmpty {
                        directorySection(title: languageService.text(.messagingSearchResults)) {
                            ForEach(viewModel.filteredRemoteUsers) { user in
                                userRow(user)
                            }
                        }
                    }

                    if !viewModel.filteredFriends.isEmpty {
                        directorySection(title: languageService.text(.friendsTabFriends)) {
                            ForEach(viewModel.filteredFriends) { user in
                                userRow(user)
                            }
                        }
                    }

                    if !viewModel.filteredGroups.isEmpty {
                        directorySection(title: languageService.text(.friendsTabGroups)) {
                            ForEach(viewModel.filteredGroups) { group in
                                groupRow(group)
                            }
                        }
                    }

                    if viewModel.filteredRemoteUsers.isEmpty,
                       viewModel.filteredFriends.isEmpty,
                       viewModel.filteredGroups.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: languageService.text(.messagingSearchEmptyTitle),
                            message: languageService.text(.messagingSelectFriend)
                        )
                        .padding(.top, SplickTheme.Spacing.xl)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.lg)
            }
        }
    }

    private func directorySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(title)
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.leading, SplickTheme.Spacing.xxs)

            VStack(spacing: SplickTheme.Spacing.xs) {
                content()
            }
        }
    }

    private func userRow(_ user: UserSummary) -> some View {
        Button {
            viewModel.toggleUser(user)
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Text("@\(user.username)")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }

                Spacer(minLength: 0)

                if viewModel.isUserSelected(user) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func groupRow(_ group: SplickDomain.Group) -> some View {
        Button {
            viewModel.selectGroup(group)
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                AvatarView(imageURL: group.avatarURL, name: group.name, size: .medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Text(languageService.format(.friendsMemberCount, group.memberCount))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                if viewModel.selectedGroup?.id == group.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func selectedUserTile(_ user: UserSummary) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

                Button {
                    viewModel.removeUser(user)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }

            Text(shortName(user))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(width: ComposeMetrics.selectedNameWidth)
        }
        .frame(width: ComposeMetrics.selectedTileWidth)
    }

    private func selectedGroupTile(_ group: SplickDomain.Group) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                AvatarView(imageURL: group.avatarURL, name: group.name, size: .medium)

                Button {
                    viewModel.removeSelectedGroup()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }

            Text(group.name)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(width: ComposeMetrics.selectedNameWidth)
        }
        .frame(width: ComposeMetrics.selectedTileWidth)
    }

    private var composeInputBar: some View {
        MessageComposerInputBar(
            text: $viewModel.messageBody,
            attachmentDrafts: $viewModel.attachmentDrafts,
            placeholder: languageService.text(.messagingInputPlaceholder),
            isSending: viewModel.isSending,
            errorMessage: viewModel.errorMessage,
            onSend: { _, submissions in
                Task { await sendMessage(submissions: submissions) }
            },
            isFocused: $isMessageFocused
        )
    }

    private func sendMessage(submissions: [CommentSubmissionAttachment]) async {
        guard let conversation = await viewModel.send(submissions: submissions) else { return }
        onSent(conversation)
        dismiss()
    }

    private func shortName(_ user: UserSummary) -> String {
        let trimmed = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return user.username }
        return trimmed.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? trimmed
    }
}
