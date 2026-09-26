import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

public struct FriendUserProfileView: View {
    @StateObject private var viewModel: FriendUserProfileViewModel
    @StateObject private var refreshController = SplickRefreshController()
    @State private var previewPost: Post?
    @State private var showAvatarViewer = false
    private let showsPersonalPageChrome: Bool
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var presenceStore: PresenceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openDirectMessage) private var openDirectMessage
    @Environment(\.openLinkedPost) private var openLinkedPost
    @Environment(\.openProfileSettings) private var openProfileSettings
    @State private var isOpeningMessage = false

    private static let postGridSpacing = SplickTheme.Spacing.xs
    private let postGridColumns = Array(
        repeating: GridItem(.flexible(), spacing: Self.postGridSpacing),
        count: 4
    )

    public init(viewModel: FriendUserProfileViewModel, showsPersonalPageChrome: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.showsPersonalPageChrome = showsPersonalPageChrome
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.lg) {
                    if viewModel.isBotProfile {
                        profileAvatarButton
                            .padding(.top, SplickTheme.Spacing.xl)

                        profileNameBlock(centered: true)

                        botProfileContent
                            .padding(.horizontal, SplickTheme.Spacing.xl)
                    } else {
                        profileIdentityRow
                            .padding(.top, SplickTheme.Spacing.xl)
                            .padding(.horizontal, SplickTheme.Spacing.md)

                        profileNameBlock(centered: false)
                            .padding(.horizontal, SplickTheme.Spacing.md)
                    }

                    if !viewModel.isBotProfile, let profileError = viewModel.profileError {
                        Text(profileError)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SplickTheme.Spacing.xl)

                        SplickButton(languageService.text(.profileRetry), style: .secondary) {
                            Task { await viewModel.loadProfile() }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, SplickTheme.Spacing.xl)
                    } else if !viewModel.isBotProfile, !viewModel.isOwnProfile {
                        relationshipActions
                            .padding(.horizontal, SplickTheme.Spacing.md)
                    }

                    if !viewModel.isBotProfile {
                        postsContent
                    }
                }
                .padding(.bottom, SplickTheme.Spacing.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(showsPersonalPageChrome ? languageService.text(.profilePersonalPage) : "")
            .toolbar {
                if showsPersonalPageChrome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel(languageService.text(.commonBack))
                    }
                } else if viewModel.isOwnProfile, let openProfileSettings {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                openProfileSettings()
                            }
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(languageService.text(.profileSettingsAccessibility))
                    }
                }
                if !showsPersonalPageChrome {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(languageService.text(.commonClose)) { dismiss() }
                    }
                }
            }
            .overlay {
                if !viewModel.isBotProfile,
                   viewModel.isLoadingProfile && viewModel.stats == nil {
                    LoadingView(message: languageService.text(.profileLoading))
                }
            }
            .task {
                async let profile: Void = viewModel.loadProfile()
                async let posts: Void = viewModel.loadPostsIfNeeded()
                _ = await (profile, posts)
            }
            .splickNativeRefreshable(controller: refreshController) {
                async let profile: Void = viewModel.loadProfile()
                async let posts: Void = viewModel.refreshPosts()
                _ = await (profile, posts)
            }
            .onChange(of: viewModel.posts.map(\.id)) { _ in
                ImagePrefetching.prefetch(urls: viewModel.posts.compactMap(profilePosterURL))
            }
            .alert(languageService.text(.profileTitle), isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button(languageService.text(.commonOK), role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .overlay(alignment: .center) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .alert(
                        languageService.text(.friendsRemoveFriendConfirmTitle),
                        isPresented: $viewModel.showRemoveConfirm
                    ) {
                        Button(languageService.text(.commonCancel), role: .cancel) {}
                        Button(languageService.text(.friendsRemoveFriendConfirmAction), role: .destructive) {
                            Task {
                                await viewModel.removeFriend()
                                if viewModel.friendStatus == .none {
                                    presenceStore.clear(userId: viewModel.user.id)
                                }
                                dismiss()
                            }
                        }
                    }
                    .alert(
                        languageService.text(.friendsBlockConfirmTitle),
                        isPresented: $viewModel.showBlockConfirm
                    ) {
                        Button(languageService.text(.commonCancel), role: .cancel) {}
                        Button(languageService.text(.friendsBlockConfirmAction), role: .destructive) {
                            Task {
                                await viewModel.blockUser()
                                if viewModel.friendStatus == .blocked {
                                    presenceStore.clear(userId: viewModel.user.id)
                                }
                                dismiss()
                            }
                        }
                    }
            }
            .sheet(isPresented: $viewModel.showNicknameEditor) {
                nicknameEditorSheet
            }
            .splickWindowFullScreenCover(isPresented: $showAvatarViewer) {
                AvatarFullScreenView(
                    url: viewModel.user.avatarURL,
                    placeholderName: viewModel.user.preferredName,
                    onDismiss: { showAvatarViewer = false }
                )
            }
            .sheet(isPresented: $viewModel.showPaymentSheet) {                FriendPaymentProfileSheet(
                    user: viewModel.user,
                    paymentProfile: viewModel.paymentProfile,
                    isLoading: viewModel.isLoadingFriendPayment,
                    notConfigured: viewModel.friendPaymentNotConfigured,
                    errorMessage: viewModel.paymentProfileError
                )
            }
            .overlay {
                if let previewPost {
                    PostPeekOverlay(
                        post: previewPost,
                        onDismiss: { self.previewPost = nil },
                        onOpen: {
                            let postId = previewPost.id
                            self.previewPost = nil
                            openPost(postId)
                        }
                    )
                    .zIndex(10)
                }
            }
        }
    }

    private var postsContent: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            Text(languageService.text(.profilePostsTitle))
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.horizontal, SplickTheme.Spacing.md)

            postsGridState
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var postsGridState: some View {
        if viewModel.isLoadingPosts && viewModel.posts.isEmpty {
            LoadingView(message: languageService.text(.profilePostsLoading))
                .frame(minHeight: 160)
                .padding(.horizontal, SplickTheme.Spacing.md)
        } else if let postsError = viewModel.postsError, viewModel.posts.isEmpty {
            ErrorView(message: postsError) {
                Task { await viewModel.refreshPosts() }
            }
            .frame(minHeight: 160)
            .padding(.horizontal, SplickTheme.Spacing.md)
        } else if viewModel.posts.isEmpty {
            EmptyStateView(
                icon: "square.grid.2x2",
                title: languageService.text(.profilePostsEmptyTitle),
                message: languageService.text(.profilePostsEmptyMessage)
            )
            .frame(minHeight: 180)
            .padding(.horizontal, SplickTheme.Spacing.md)
        } else {
            LazyVGrid(columns: postGridColumns, spacing: Self.postGridSpacing) {
                ForEach(viewModel.posts) { post in
                    profilePostCell(post)
                        .onAppear {
                            Task {
                                await viewModel.loadMorePostsIfNeeded(currentPostId: post.id)
                            }
                        }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)

            if viewModel.isLoadingMorePosts {
                SplickSpinner()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.md)
            } else if let postsError = viewModel.postsError {
                VStack(spacing: SplickTheme.Spacing.xs) {
                    Text(postsError)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                    Button(languageService.text(.profileRetry)) {
                        guard let lastPostId = viewModel.posts.last?.id else { return }
                        Task {
                            await viewModel.loadMorePostsIfNeeded(currentPostId: lastPostId)
                        }
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
        }
    }

    private func profilePostCell(_ post: Post) -> some View {
        let cellShape = RoundedRectangle(
            cornerRadius: SplickTheme.CornerRadius.small,
            style: .continuous
        )
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                profilePostThumbnail(post)
            }
            .overlay(alignment: .topTrailing) {
                if post.mediaItems.count > 1 {
                    Image(systemName: "square.fill.on.square.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .padding(6)
                } else if post.mediaType == .video {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .padding(6)
                }
            }
            .clipShape(cellShape)
            .contentShape(cellShape)
            .overlay {
                GridPressCatcher(
                    onTap: {
                        guard previewPost == nil else { return }
                        openPost(post.id)
                    },
                    onLongPress: {
                        previewPost = post
                    }
                )
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(languageService.text(.profileStatPosts))
    }

    @ViewBuilder
    private func profilePostThumbnail(_ post: Post) -> some View {
        if let poster = profilePosterURL(post) {
            GridThumbnailImage(url: poster) {
                SplickTheme.Colors.cardBackground
            }
        } else if let videoURL = profileVideoURL(post) {
            ProfileVideoFirstFrame(videoURL: videoURL)
        } else {
            SplickTheme.Colors.cardBackground
        }
    }

    private func profilePosterURL(_ post: Post) -> URL? {
        let media = post.displayMediaItems.first
        let isVideo = (media?.mediaType ?? post.mediaType) == .video
        let videoURL = media?.mediaURL ?? post.videoURL ?? post.imageURL
        if isVideo {
            return VideoPosterURL.usableImageURL(media?.thumbnailURL ?? post.thumbnailURL, videoURL: videoURL)
        }
        return media?.thumbnailURL ?? post.thumbnailURL ?? post.imageURL
    }

    private func profileVideoURL(_ post: Post) -> URL? {
        let media = post.displayMediaItems.first
        let isVideo = (media?.mediaType ?? post.mediaType) == .video
        guard isVideo else { return nil }
        return media?.mediaURL ?? post.videoURL
    }

    private func openPost(_ postId: UUID) {
        guard let openLinkedPost else { return }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            openLinkedPost(postId, false, false)
        }
    }

    private var profileAvatarButton: some View {
        Button {
            showAvatarViewer = true
        } label: {
            AvatarWithPresenceView(
                imageURL: viewModel.user.avatarURL,
                name: viewModel.user.preferredName,
                size: .profile,
                userId: viewModel.user.id,
                showOnlineIndicator: viewModel.isOwnProfile || (
                    viewModel.friendStatus == .friends &&
                    PresenceDisplayPolicy.shouldShowOnlineIndicator(
                        isOnline: resolvedPresence.isOnline
                    )
                ),
                lastSeenLabel: viewModel.isOwnProfile || viewModel.friendStatus != .friends
                    ? nil
                    : PresenceDisplayPolicy.compactLastSeenLabel(
                        isOnline: resolvedPresence.isOnline,
                        lastSeenAt: resolvedPresence.lastSeenAt,
                        appLocale: languageService.locale
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func profileNameBlock(centered: Bool) -> some View {
        let alignment: Alignment = centered ? .center : .leading
        return VStack(alignment: centered ? .center : .leading, spacing: SplickTheme.Spacing.xxs) {
            Text(viewModel.user.dualDisplayName)
                .font(
                    centered
                        ? SplickTheme.Typography.largeTitle
                        : .system(size: 40, weight: .bold, design: .rounded)
                )
                .multilineTextAlignment(centered ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: alignment)
            if viewModel.isBotProfile {
                Text(languageService.text(.splickBotProfileTagline))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Text("@\(viewModel.user.username)")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(centered ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
    }

    private var profileIdentityRow: some View {
        HStack(alignment: .center, spacing: 0) {
            profileAvatarButton
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear
                .frame(maxWidth: .infinity)
            Color.clear
                .frame(maxWidth: .infinity)
        }
        .overlay {
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: 0) {
                    Color.clear
                        .frame(width: proxy.size.width / 3)
                    if let stats = viewModel.stats {
                        statsRow(stats)
                            .frame(width: proxy.size.width * 2 / 3)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .allowsHitTesting(false)
        }
    }

    private func statsRow(_ stats: UserProfileStats) -> some View {
        HStack(spacing: 0) {
            statBlock(
                value: stats.friendCount,
                label: languageService.text(.profileStatFriends),
                prominent: true
            )
            Spacer(minLength: 4)
            statBlock(
                value: stats.postCount,
                label: languageService.text(.profileStatPosts),
                prominent: true
            )
            Spacer(minLength: 4)
            statBlock(
                value: stats.groupCount,
                label: languageService.text(.profileStatGroups),
                prominent: true
            )
        }
    }

    private func statBlock(value: Int, label: String, prominent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(
                    prominent
                        ? .system(.title, design: .rounded, weight: .semibold)
                        : SplickTheme.Typography.title
                )
                .lineLimit(1)
            Text(label)
                .font(prominent ? .system(.subheadline) : SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SplickTheme.Typography.title)
            Text(label)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
    }

    private var botProfileContent: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            HStack(spacing: SplickTheme.Spacing.xl) {
                statBlock(
                    value: "\(SplickBot.remindersSentCount.formatted())+",
                    label: languageService.text(.splickBotStatReminders)
                )
                statBlock(
                    value: languageService.text(.splickBotStatRecoveryValue),
                    label: languageService.text(.splickBotStatRecovery)
                )
                statBlock(
                    value: languageService.text(.splickBotStatExperienceValue),
                    label: languageService.text(.splickBotStatExperience)
                )
            }
            .padding(.top, SplickTheme.Spacing.md)

            Text(languageService.text(.splickBotProfileBio))
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(SplickTheme.Spacing.md)
                .background(SplickTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
        }
    }

    @ViewBuilder
    private var relationshipActions: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            switch viewModel.mode {
            case .friend:
                friendActionGrid

            case .stranger:
                switch viewModel.friendStatus {
                case .none:
                    SplickButton(languageService.text(.feedProfileAddFriend)) {
                        Task { await viewModel.addFriend() }
                    }
                    .disabled(viewModel.isProcessing)
                case .requestReceived:
                    SplickButton(languageService.text(.friendsAccept)) {
                        Task { await viewModel.acceptFriendRequest() }
                    }
                    .disabled(viewModel.isProcessing)
                case .requestSent:
                    SplickButton(languageService.text(.friendsRecallRequest), style: .destructive) {
                        Task { await viewModel.cancelFriendRequest() }
                    }
                    .disabled(viewModel.isProcessing)
                default:
                    EmptyView()
                }

                Button(languageService.text(.friendsBlockUser)) {
                    viewModel.showBlockConfirm = true
                }
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.red)
                .disabled(viewModel.isProcessing)

            case .blocked:
                SplickButton(languageService.text(.friendsUnblock), style: .secondary) {
                    Task {
                        await viewModel.unblockUser()
                        dismiss()
                    }
                }
                .disabled(viewModel.isProcessing)
            }

            if viewModel.isProcessing {
                SplickSpinner()
            }
        }
    }

    private var friendActionGrid: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                if let openDM = openDirectMessage {
                    ProfileCompactActionButton(
                        icon: "message.fill",
                        title: languageService.text(.messagingMessageButton),
                        tint: SplickTheme.Colors.primaryGradientStart,
                        isDisabled: viewModel.isProcessing || isOpeningMessage
                    ) {
                        guard !isOpeningMessage else { return }
                        isOpeningMessage = true
                        Task { @MainActor in
                            let conversationId = await openDM(viewModel.user.id)
                            if conversationId != nil {
                                dismiss()
                            } else {
                                isOpeningMessage = false
                            }
                        }
                    }
                }

                ProfileCompactActionButton(
                    icon: "person.text.rectangle",
                    title: languageService.text(.friendsSetNickname),
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showNicknameEditor = true
                }

                ProfileCompactActionButton(
                    icon: "qrcode",
                    title: languageService.text(.profilePaymentManage),
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showPaymentSheet = true
                }
            }

            HStack(spacing: SplickTheme.Spacing.xs) {
                ProfileCompactActionButton(
                    icon: "person.badge.minus",
                    title: languageService.text(.friendsRemoveFriend),
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showRemoveConfirm = true
                }

                ProfileCompactActionButton(
                    icon: "hand.raised.fill",
                    title: languageService.text(.friendsBlockUser),
                    tint: SplickTheme.Colors.error,
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showBlockConfirm = true
                }

                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var nicknameEditorSheet: some View {
        NavigationStack {
            Form {
                TextField(languageService.text(.friendsNicknamePlaceholder), text: $viewModel.nicknameDraft)
                    .autocorrectionDisabled()
            }
            .navigationTitle(languageService.text(.friendsNicknameTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { viewModel.showNicknameEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonSave)) {
                        Task { await viewModel.saveNickname() }
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var resolvedPresence: (isOnline: Bool, lastSeenAt: Date?) {
        _ = presenceStore.states
        let stored = presenceStore.state(for: viewModel.user.id)
        let isOnline = (stored?.isOnline == true) || viewModel.profileIsOnline
        let lastSeenAt = stored?.lastSeenAt ?? viewModel.profileLastSeenAt
        return (isOnline, lastSeenAt)
    }
}

private struct ProfileVideoFirstFrame: View {
    let videoURL: URL
    @State private var generatedFrame: UIImage?

    var body: some View {
        Group {
            if let generatedFrame {
                Image(uiImage: generatedFrame)
                    .resizable()
                    .scaledToFill()
            } else {
                SplickTheme.Colors.cardBackground
            }
        }
        .task(id: videoURL.absoluteString) {
            if let cached = await VideoFirstFrameCache.shared.image(for: videoURL) {
                generatedFrame = cached
                return
            }
            generatedFrame = await VideoFirstFrameCache.shared.generate(for: videoURL)
        }
    }
}
