import SwiftUI
import PhotosUI
import DesignSystem
import Localization
import SplickDomain

private enum CreateGroupMetrics {
    static let fieldCornerRadius: CGFloat = SplickTheme.CornerRadius.inset
    static let avatarSize: CGFloat = 96
    static let memberTileWidth: CGFloat = 72
    static let memberNameWidth: CGFloat = 64
}

public struct CreateGroupSheet: View {
    @ObservedObject var viewModel: CreateGroupViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMemberSearchFocused: Bool

    public init(viewModel: CreateGroupViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    avatarSection

                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                        Text(languageService.text(.friendsGroupName))
                            .font(SplickTheme.Typography.headline)

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
                    }
                    .splickCard()

                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                        Text(languageService.text(.friendsGroupDescriptionOptional))
                            .font(SplickTheme.Typography.headline)

                        TextField(
                            languageService.text(.friendsGroupDescriptionPlaceholder),
                            text: $viewModel.groupDescription,
                            axis: .vertical
                        )
                            .lineLimit(3...6)
                            .padding(SplickTheme.Spacing.sm)
                            .frame(minHeight: 88, alignment: .topLeading)
                            .background(SplickTheme.Colors.tertiaryBackground)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: CreateGroupMetrics.fieldCornerRadius,
                                    style: .continuous
                                )
                            )
                    }
                    .splickCard()

                    membersSection

                    if let success = viewModel.successMessage {
                        Text(success)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.success)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
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
                .padding(.bottom, SplickTheme.Spacing.xl)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.friendsCreateGroup))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                groupAvatarPreview
            }
            .onChange(of: viewModel.selectedPhotoItem) { _ in
                Task { await viewModel.onPhotoItemChanged() }
            }

            Text(languageService.text(.friendsGroupAvatar))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SplickTheme.Spacing.xs)
    }

    @ViewBuilder
    private var groupAvatarPreview: some View {
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
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.secondaryBackground)
                    .frame(width: CreateGroupMetrics.avatarSize, height: CreateGroupMetrics.avatarSize)

                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                    Text(languageService.text(.friendsGroupPickPhoto))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.messagingGroupMembersTitle))
                .font(SplickTheme.Typography.headline)

            if viewModel.friends.isEmpty {
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
                }

                if viewModel.shouldShowMemberSuggestions {
                    memberSearchResultsList
                }
            }
        }
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
            VStack(spacing: 0) {
                ForEach(viewModel.filteredFriends) { friend in
                    HStack(spacing: SplickTheme.Spacing.sm) {
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
                        }

                        Button {
                            viewModel.addMember(friend)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, 10)

                    if friend.id != viewModel.filteredFriends.last?.id {
                        Divider().padding(.leading, 48)
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
