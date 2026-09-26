import SwiftUI
import PhotosUI
import Common
import DesignSystem
import FeatureMedia
import Localization
import SplickDomain

private enum CreateGroupMetrics {
    static let fieldCornerRadius: CGFloat = SplickTheme.CornerRadius.inset
    static let avatarSize: CGFloat = 96
    static let memberTileWidth: CGFloat = 72
    static let memberNameWidth: CGFloat = 64
}

public struct CreateGroupSheet: View {
    @StateObject private var viewModel: CreateGroupViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMemberSearchFocused: Bool

    public init(viewModel: CreateGroupViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public init(
        friends: [UserSummary] = [],
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        createGroupUseCase: CreateGroupUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol,
        updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol,
        openLinkedGroupConversation: @escaping (_ groupId: UUID, _ name: String, _ memberUserIds: [UUID]) async throws -> Void = { _, _, _ in },
        languageService: LanguageService,
        onSuccess: @escaping (SplickDomain.Group, [UUID]) -> Void
    ) {
        self._viewModel = StateObject(
            wrappedValue: CreateGroupViewModel(
                friends: friends,
                fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                createGroupUseCase: createGroupUseCase,
                inviteFriendsUseCase: inviteFriendsUseCase,
                uploadGroupAvatarUseCase: uploadGroupAvatarUseCase,
                updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                openLinkedGroupConversation: openLinkedGroupConversation,
                languageService: languageService,
                onSuccess: onSuccess
            )
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                    avatarSection
                    detailsCard
                }

                membersSection
                    .frame(maxHeight: .infinity, alignment: .top)

                if let success = viewModel.successMessage {
                    Text(success)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SplickButton(
                    languageService.text(.friendsCreateGroup),
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.canSubmit
                ) {
                    Task { await viewModel.create() }
                }
            }
            .padding(SplickTheme.Spacing.md)
            .animation(.easeInOut(duration: 0.2), value: viewModel.showsMemberPopup)
            .background(SplickTheme.Colors.background)
            .dismissKeyboardOnTap()
            .navigationTitle(languageService.text(.friendsCreateGroup))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
            .task {
                await viewModel.loadFriendsIfNeeded()
            }
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            TextField(languageService.text(.friendsGroupNamePlaceholder), text: $viewModel.name)
                .textInputAutocapitalization(.words)
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.tertiaryBackground)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: CreateGroupMetrics.fieldCornerRadius,
                        style: .continuous
                    )
                )

            TextField(
                languageService.text(.friendsGroupDescriptionPlaceholder),
                text: $viewModel.groupDescription,
                axis: .vertical
            )
            .lineLimit(2...4)
            .padding(SplickTheme.Spacing.sm)
            .frame(minHeight: 72, alignment: .topLeading)
            .background(SplickTheme.Colors.tertiaryBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: CreateGroupMetrics.fieldCornerRadius,
                    style: .continuous
                )
            )
        }
        .splickCard()
    }

    private var avatarSection: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                groupAvatarPreview
            }
            .onChange(of: viewModel.selectedPhotoItem) { _ in
                Task { await viewModel.onPhotoItemChanged() }
            }

            Text(
                languageService.text(
                    viewModel.previewImage == nil ? .friendsGroupPickPhoto : .friendsGroupAvatar
                )
            )
            .font(SplickTheme.Typography.caption.weight(.medium))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SplickTheme.Spacing.xs)
    }

    @ViewBuilder
    private var groupAvatarPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            if let preview = viewModel.previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: CreateGroupMetrics.avatarSize, height: CreateGroupMetrics.avatarSize)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
            } else {
                Circle()
                    .fill(SplickTheme.Colors.secondaryBackground)
                    .frame(width: CreateGroupMetrics.avatarSize, height: CreateGroupMetrics.avatarSize)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
            }

            Image(systemName: "camera.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(SplickTheme.Colors.primaryGradientStart)
                .clipShape(Circle())
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack {
                Text(languageService.text(.messagingGroupMembersTitle))
                    .font(SplickTheme.Typography.headline)
                Spacer()
                if !viewModel.selectedMembers.isEmpty {
                    Text("\(viewModel.selectedMembers.count)")
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
            }

            if viewModel.isLoadingFriends {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    SplickSpinner()
                    Text(languageService.text(.commonLoading))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SplickTheme.Spacing.xs)
            } else if let friendsLoadErrorMessage = viewModel.friendsLoadErrorMessage {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text(friendsLoadErrorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)

                    Button(languageService.text(.commonTryAgain)) {
                        Task { await viewModel.loadFriends() }
                    }
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
            } else if viewModel.friends.isEmpty {
                Text(languageService.text(.friendsGroupNoFriendsToInvite))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            } else {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                    TextField(languageService.text(.expenseFilterSearchFriends), text: $viewModel.memberSearchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isMemberSearchFocused)
                        .onChange(of: isMemberSearchFocused) { focused in
                            viewModel.setMemberSearchFocused(focused)
                        }
                }
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.tertiaryBackground)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: CreateGroupMetrics.fieldCornerRadius,
                        style: .continuous
                    )
                )

                if !viewModel.selectedMembers.isEmpty {
                    selectedMembersStrip
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if viewModel.showsMemberPopup {
                    memberSearchResultsList
                        .frame(maxWidth: .infinity, maxHeight: 280, alignment: .top)
                        .background(SplickTheme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.24), value: viewModel.selectedMemberIds)
        .splickCard()
    }

    private var selectedMembersStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                ForEach(viewModel.selectedMembers) { friend in
                    selectedMemberTile(for: friend)
                }
            }
            .padding(.vertical, SplickTheme.Spacing.xxxs)
        }
    }

    private func selectedMemberTile(for friend: UserSummary) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                AvatarView(
                    imageURL: friend.avatarURL,
                    name: friend.displayName,
                    size: .medium
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            SplickTheme.Colors.primaryGradientStart.opacity(0.18),
                            lineWidth: 1
                        )
                }

                Button {
                    viewModel.removeMember(friend)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }

            Text(memberShortName(friend))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(width: CreateGroupMetrics.memberNameWidth)
        }
        .frame(width: CreateGroupMetrics.memberTileWidth)
        .padding(.vertical, SplickTheme.Spacing.xxs)
    }

    @ViewBuilder
    private var memberSearchResultsList: some View {
        if viewModel.filteredFriends.isEmpty {
            Text(languageService.text(.feedAudienceFriendsNotFound))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SplickTheme.Spacing.sm)
        } else {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.filteredFriends) { friend in
                        Button {
                            viewModel.addMember(friend)
                        } label: {
                            HStack(spacing: SplickTheme.Spacing.sm) {
                                AvatarView(
                                    imageURL: friend.avatarURL,
                                    name: friend.displayName,
                                    size: .small
                                )
                                .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(SplickTheme.Typography.callout)
                                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                                    Text("@\(friend.username)")
                                        .font(SplickTheme.Typography.caption)
                                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                    .frame(width: 28, height: 28)
                                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .padding(.horizontal, SplickTheme.Spacing.sm)
                            .padding(.vertical, 8)
                            .background(SplickTheme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.pill, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func memberShortName(_ user: UserSummary) -> String {
        let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return user.username }
        let shortName = trimmedName.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? trimmedName
        return shortName
    }
}
