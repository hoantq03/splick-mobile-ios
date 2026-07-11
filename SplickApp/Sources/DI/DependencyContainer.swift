import Foundation
import Networking
import Storage
import Common
import Localization
import SplickDomain
import FeatureAuth
import FeatureSocialFeed
import FeatureMedia
import FeatureExpense
import FeatureNotification
import FeatureFriends
import FeatureMessaging
import FeatureStickers
import SplickWidgetKit

@MainActor
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    // MARK: - Core

    let tokenProvider: TokenProvider
    let keychainService: KeychainServiceProtocol
    let userDefaultsService: UserDefaultsServiceProtocol
    let languageService: LanguageService

    let apiClient: APIClientProtocol
    let sessionManager: SessionManagerProtocol

    // MARK: - Auth (always live API)

    private let authRepository: AuthRepositoryProtocol
    let refreshTokenUseCase: RefreshTokenUseCaseProtocol
    let restoreSessionUseCase: RestoreSessionUseCaseProtocol

    lazy var checkIdentifierUseCase: CheckIdentifierUseCaseProtocol = {
        CheckIdentifierUseCase(repository: authRepository)
    }()

    lazy var checkUsernameAvailabilityUseCase: CheckUsernameAvailabilityUseCaseProtocol = {
        CheckUsernameAvailabilityUseCase(repository: authRepository)
    }()

    lazy var loginUseCase: LoginUseCaseProtocol = {
        LoginUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol = {
        RequestEmailOtpUseCase(repository: authRepository)
    }()

    lazy var requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol = {
        RequestPhoneOtpUseCase(repository: authRepository)
    }()

    lazy var verifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol = {
        VerifyPhoneOtpUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var googleSignInUseCase: GoogleSignInUseCaseProtocol = {
        GoogleSignInUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var appleSignInUseCase: AppleSignInUseCaseProtocol = {
        AppleSignInUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var registerUseCase: RegisterUseCaseProtocol = {
        RegisterUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var logoutUseCase: LogoutUseCaseProtocol = {
        LogoutUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var forgotPasswordUseCase: ForgotPasswordUseCaseProtocol = {
        ForgotPasswordUseCase(repository: authRepository)
    }()

    lazy var resetPasswordUseCase: ResetPasswordUseCaseProtocol = {
        ResetPasswordUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var verifyResetPasswordOtpUseCase: VerifyResetPasswordOtpUseCaseProtocol = {
        VerifyResetPasswordOtpUseCase(repository: authRepository)
    }()

    lazy var changePasswordUseCase: ChangePasswordUseCaseProtocol = {
        ChangePasswordUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol = {
        VerifyPasswordChangeUseCase(repository: authRepository)
    }()

    lazy var refreshProfileUseCase: RefreshProfileUseCaseProtocol = {
        RefreshProfileUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var updateProfileUseCase: UpdateProfileUseCaseProtocol = {
        UpdateProfileUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var listSessionsUseCase: ListSessionsUseCaseProtocol = {
        ListSessionsUseCase(repository: authRepository)
    }()

    lazy var revokeSessionUseCase: RevokeSessionUseCaseProtocol = {
        RevokeSessionUseCase(repository: authRepository)
    }()

    lazy var revokeAllSessionsUseCase: RevokeAllSessionsUseCaseProtocol = {
        RevokeAllSessionsUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var deactivateAccountUseCase: DeactivateAccountUseCaseProtocol = {
        DeactivateAccountUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var deleteAccountUseCase: DeleteAccountUseCaseProtocol = {
        DeleteAccountUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol = {
        GetConnectedAccountsUseCase(repository: authRepository)
    }()

    lazy var linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol = {
        LinkGoogleAccountUseCase(repository: authRepository)
    }()

    lazy var unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol = {
        UnlinkGoogleAccountUseCase(repository: authRepository)
    }()

    lazy var linkPhoneAccountUseCase: LinkPhoneAccountUseCaseProtocol = {
        LinkPhoneAccountUseCase(repository: authRepository)
    }()

    lazy var linkEmailAccountUseCase: LinkEmailAccountUseCaseProtocol = {
        LinkEmailAccountUseCase(repository: authRepository)
    }()

    // MARK: - Media

    private lazy var mediaRepository: MediaRepositoryProtocol = {
        MediaRepository(apiClient: apiClient)
    }()

    lazy var uploadMediaUseCase: UploadMediaUseCaseProtocol = {
        UploadMediaUseCase(repository: mediaRepository)
    }()

    func uploadCommentAttachment(data: Data, mimeType: String) async throws -> MediaUploadResult {
        try await mediaRepository.uploadImage(
            data: data,
            mimeType: mimeType,
            purpose: .commentAttachment,
            groupId: nil
        )
    }

    lazy var uploadUserAvatarUseCase: UploadUserAvatarUseCaseProtocol = {
        UploadUserAvatarUseCase(repository: mediaRepository)
    }()

    lazy var uploadPaymentQrUseCase: UploadPaymentQrUseCaseProtocol = {
        UploadPaymentQrUseCase(repository: mediaRepository)
    }()

    lazy var fetchMyPaymentProfileUseCase: FetchMyPaymentProfileUseCaseProtocol = {
        FetchMyPaymentProfileUseCase(repository: authRepository)
    }()

    lazy var upsertMyPaymentProfileUseCase: UpsertMyPaymentProfileUseCaseProtocol = {
        UpsertMyPaymentProfileUseCase(repository: authRepository)
    }()

    lazy var deleteMyPaymentProfileUseCase: DeleteMyPaymentProfileUseCaseProtocol = {
        DeleteMyPaymentProfileUseCase(repository: authRepository)
    }()

    lazy var uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol = {
        UploadGroupAvatarUseCase(repository: mediaRepository)
    }()

    // MARK: - Stickers

    private lazy var stickerRepository: StickerRepositoryProtocol = {
        StickerRepositoryImpl(apiClient: apiClient)
    }()

    lazy var fetchStickersUseCase: FetchStickersUseCaseProtocol = {
        FetchStickersUseCase(repository: stickerRepository)
    }()

    func makeGifPickerViewModel(groupId: UUID?) -> GifPickerViewModel {
        GifPickerViewModel(fetchStickersUseCase: fetchStickersUseCase, groupId: groupId)
    }

    lazy var customEmojiRepository: CustomEmojiRepositoryProtocol = {
        CustomEmojiRepository(apiClient: apiClient)
    }()

    lazy var fetchAllCustomEmojisUseCase: FetchAllCustomEmojisUseCaseProtocol = {
        FetchAllCustomEmojisUseCase(repository: customEmojiRepository)
    }()

    lazy var addUserCustomEmojiUseCase: AddUserCustomEmojiUseCaseProtocol = {
        AddUserCustomEmojiUseCase(repository: customEmojiRepository)
    }()

    lazy var deleteUserCustomEmojiUseCase: DeleteUserCustomEmojiUseCaseProtocol = {
        DeleteUserCustomEmojiUseCase(repository: customEmojiRepository)
    }()

    let customEmojiStore = CustomEmojiStore()

    var customEmojiDependencies: CustomEmojiDependencies {
        CustomEmojiDependencies(
            fetcher: customEmojiRepository,
            uploadMediaUseCase: uploadMediaUseCase,
            addEmojiUseCase: addUserCustomEmojiUseCase,
            deleteEmojiUseCase: deleteUserCustomEmojiUseCase
        )
    }

    // MARK: - Feed

    private lazy var feedRepository: FeedRepositoryProtocol = {
        FeedRepository(apiClient: apiClient, mediaRepository: mediaRepository)
    }()

    lazy var fetchFeedUseCase: FetchFeedUseCaseProtocol = {
        FetchFeedUseCase(repository: feedRepository)
    }()

    lazy var fetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol = {
        FetchPhotoAlbumUseCase(repository: feedRepository)
    }()

    lazy var fetchStreakUseCase: FetchStreakUseCaseProtocol = {
        FetchStreakUseCase(repository: feedRepository)
    }()

    lazy var fetchPostUseCase: FetchPostUseCaseProtocol = {
        FetchPostUseCase(repository: feedRepository)
    }()

    lazy var reactToPostUseCase: ReactToPostUseCaseProtocol = {
        ReactToPostUseCase(repository: feedRepository)
    }()

    lazy var deletePostUseCase: DeletePostUseCaseProtocol = {
        DeletePostUseCase(repository: feedRepository)
    }()

    lazy var createPostUseCase: CreatePostUseCaseProtocol = {
        CreatePostUseCase(repository: feedRepository)
    }()

    lazy var addCommentUseCase: AddCommentUseCaseProtocol = {
        AddCommentUseCase(repository: feedRepository)
    }()

    lazy var sendBillReminderUseCase: SendBillReminderUseCaseProtocol = {
        SendBillReminderUseCase(repository: feedRepository)
    }()

    lazy var submitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol = {
        SubmitPaymentEvidenceUseCase(repository: feedRepository)
    }()

    lazy var approvePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol = {
        ApprovePaymentEvidenceUseCase(repository: feedRepository)
    }()

    lazy var rejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol = {
        RejectPaymentEvidenceUseCase(repository: feedRepository)
    }()

    private lazy var friendsManagementRepository: FriendsManagementRepositoryProtocol = {
        FriendsManagementRepository(apiClient: apiClient)
    }()

    private lazy var friendsRepository: FriendsRepositoryProtocol = {
        FriendsRepository(searchRepository: friendsManagementRepository)
    }()

    private lazy var groupsRepository: GroupsRepositoryProtocol = {
        GroupsRepository(apiClient: apiClient)
    }()

    lazy var fetchFriendsUseCase: FetchFriendsUseCaseProtocol = {
        FetchFriendsUseCase(repository: friendsRepository)
    }()

    lazy var fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol = {
        FetchMyFriendsUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol = {
        FetchUserProfileUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol = {
        FetchFriendPaymentProfileUseCase(repository: friendsManagementRepository)
    }()

    lazy var friendUserProfileDependencies: FriendUserProfileDependencies = {
        FriendUserProfileDependencies(
            fetchUserProfileUseCase: fetchUserProfileUseCase,
            fetchFriendPaymentProfileUseCase: fetchFriendPaymentProfileUseCase,
            addFriendUseCase: addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoingFriendRequestsUseCase,
            acceptFriendRequestUseCase: acceptFriendRequestUseCase,
            cancelFriendRequestUseCase: cancelFriendRequestUseCase,
            removeFriendUseCase: removeFriendUseCase,
            setFriendNicknameUseCase: setFriendNicknameUseCase,
            blockUserUseCase: blockUserUseCase,
            unblockUserUseCase: unblockUserUseCase
        )
    }()

    lazy var searchUsersUseCase: SearchUsersUseCaseProtocol = {
        SearchUsersUseCase(repository: friendsManagementRepository)
    }()

    lazy var expenseFriendSearchUseCase: UserSearchUseCaseProtocol = {
        FriendsUserSearchAdapter(fetchFriendsUseCase: fetchFriendsUseCase)
    }()

    lazy var generateMyQrUseCase: GenerateMyQrUseCaseProtocol = {
        GenerateMyQrUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol = {
        FetchMyGroupsUseCase(repository: groupsRepository)
    }()

    lazy var addFriendUseCase: AddFriendUseCaseProtocol = {
        AddFriendUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol = {
        FetchIncomingFriendRequestsUseCase(repository: friendsManagementRepository)
    }()

    lazy var acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol = {
        AcceptFriendRequestUseCase(repository: friendsManagementRepository)
    }()

    lazy var rejectFriendRequestUseCase: RejectFriendRequestUseCaseProtocol = {
        RejectFriendRequestUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol = {
        FetchOutgoingFriendRequestsUseCase(repository: friendsManagementRepository)
    }()

    lazy var cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol = {
        CancelFriendRequestUseCase(repository: friendsManagementRepository)
    }()

    lazy var removeFriendUseCase: RemoveFriendUseCaseProtocol = {
        RemoveFriendUseCase(repository: friendsManagementRepository)
    }()

    lazy var setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol = {
        SetFriendNicknameUseCase(repository: friendsManagementRepository)
    }()

    lazy var blockUserUseCase: BlockUserUseCaseProtocol = {
        BlockUserUseCase(repository: friendsManagementRepository)
    }()

    lazy var unblockUserUseCase: UnblockUserUseCaseProtocol = {
        UnblockUserUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol = {
        FetchBlockedUsersUseCase(repository: friendsManagementRepository)
    }()

    lazy var joinGroupUseCase: JoinGroupUseCaseProtocol = {
        JoinGroupUseCase(repository: groupsRepository)
    }()

    lazy var createGroupUseCase: CreateGroupUseCaseProtocol = {
        CreateGroupUseCase(repository: groupsRepository)
    }()

    lazy var fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol = {
        FetchGroupMembersUseCase(repository: groupsRepository)
    }()

    lazy var fetchGroupInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol = {
        FetchGroupInviteCodeUseCase(repository: groupsRepository)
    }()

    lazy var generateGroupInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol = {
        GenerateGroupInviteCodeUseCase(repository: groupsRepository)
    }()

    lazy var inviteFriendsToGroupUseCase: InviteFriendsToGroupUseCaseProtocol = {
        InviteFriendsToGroupUseCase(repository: groupsRepository)
    }()

    lazy var fetchGroupUseCase: FetchGroupUseCaseProtocol = {
        FetchGroupUseCase(repository: groupsRepository)
    }()

    lazy var approveGroupMemberUseCase: ApproveGroupMemberUseCaseProtocol = {
        ApproveGroupMemberUseCase(repository: groupsRepository)
    }()

    lazy var rejectGroupMemberUseCase: RejectGroupMemberUseCaseProtocol = {
        RejectGroupMemberUseCase(repository: groupsRepository)
    }()

    lazy var removeGroupMemberUseCase: RemoveGroupMemberUseCaseProtocol = {
        RemoveGroupMemberUseCase(repository: groupsRepository)
    }()

    lazy var leaveGroupUseCase: LeaveGroupUseCaseProtocol = {
        LeaveGroupUseCase(repository: groupsRepository)
    }()

    lazy var deleteGroupUseCase: DeleteGroupUseCaseProtocol = {
        DeleteGroupUseCase(repository: groupsRepository)
    }()

    lazy var updateGroupUseCase: UpdateGroupUseCaseProtocol = {
        UpdateGroupUseCase(repository: groupsRepository)
    }()

    lazy var updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol = {
        UpdateGroupAvatarUseCase(repository: groupsRepository)
    }()

    lazy var transferGroupOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol = {
        TransferGroupOwnershipUseCase(repository: groupsRepository)
    }()

    lazy var generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol = {
        GenerateGroupQrUseCase(repository: groupsRepository)
    }()

    lazy var revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol = {
        RevokeGroupQrUseCase(repository: groupsRepository)
    }()

    // MARK: - Expense

    private lazy var expenseRepository: ExpenseRepositoryProtocol = {
        ExpenseRepository(apiClient: apiClient)
    }()

    lazy var fetchExpensesUseCase: FetchExpensesUseCaseProtocol = {
        FetchExpensesUseCase(repository: expenseRepository)
    }()

    lazy var createExpenseUseCase: CreateExpenseUseCaseProtocol = {
        CreateExpenseUseCase(repository: expenseRepository)
    }()

    lazy var fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol = {
        FetchDebtSummaryUseCase(repository: expenseRepository)
    }()

    // MARK: - Notification

    private lazy var notificationRepository: NotificationRepositoryProtocol = {
        NotificationRepository(apiClient: apiClient)
    }()

    lazy var fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol = {
        FetchNotificationsUseCase(repository: notificationRepository)
    }()

    lazy var markNotificationReadUseCase: MarkNotificationReadUseCaseProtocol = {
        MarkNotificationReadUseCase(repository: notificationRepository)
    }()

    lazy var markNotificationClickedUseCase: MarkNotificationClickedUseCaseProtocol = {
        MarkNotificationClickedUseCase(repository: notificationRepository)
    }()

    lazy var fetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol = {
        FetchBadgeCountsUseCase(repository: notificationRepository)
    }()

    lazy var registerPushDeviceTokenUseCase: RegisterPushDeviceTokenUseCaseProtocol = {
        RegisterPushDeviceTokenUseCase(repository: notificationRepository)
    }()

    lazy var unregisterPushDeviceTokenUseCase: UnregisterPushDeviceTokenUseCaseProtocol = {
        UnregisterPushDeviceTokenUseCase(repository: notificationRepository)
    }()

    lazy var deviceTokenService: DeviceTokenServiceProtocol = {
        DeviceTokenService(
            registerUseCase: registerPushDeviceTokenUseCase,
            unregisterUseCase: unregisterPushDeviceTokenUseCase
        )
    }()

    lazy var badgeCountService: BadgeCountService = {
        BadgeCountService(fetchBadgeCountsUseCase: fetchBadgeCountsUseCase)
    }()

    lazy var widgetSyncBridge: WidgetSyncBridge = {
        WidgetSyncBridge(
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            fetchExpensesUseCase: fetchExpensesUseCase,
            fetchDebtSummaryUseCase: fetchDebtSummaryUseCase
        )
    }()

    lazy var appStartupRepository: AppStartupRepositoryProtocol = {
        AppStartupRepository(apiClient: apiClient)
    }()

    lazy var fetchAppStartupUseCase: FetchAppStartupUseCaseProtocol = {
        FetchAppStartupUseCase(repository: appStartupRepository)
    }()

    lazy var appStartupCoordinator: AppStartupCoordinator = {
        AppStartupCoordinator(fetchAppStartupUseCase: fetchAppStartupUseCase)
    }()

    // MARK: - Messaging

    lazy var messagingWebSocketClient: MessagingWebSocketClient = {
        MessagingWebSocketClient(tokenProvider: { [weak self] in
            await self?.tokenProvider.accessToken()
        })
    }()

    private lazy var messagingRepository: MessagingRepositoryProtocol = {
        MessagingRepository(apiClient: apiClient)
    }()

    private lazy var fetchConversationsUseCase: FetchConversationsUseCase = {
        FetchConversationsUseCase(repository: messagingRepository)
    }()

    private lazy var fetchMessagesUseCase: FetchMessagesUseCase = {
        FetchMessagesUseCase(repository: messagingRepository)
    }()

    private lazy var sendMessageUseCase: SendMessageUseCase = {
        SendMessageUseCase(repository: messagingRepository)
    }()

    private lazy var reactToMessageUseCase: ReactToMessageUseCase = {
        ReactToMessageUseCase(repository: messagingRepository)
    }()

    func makeNewMessageComposeViewModel(currentUserId: UUID) -> NewMessageComposeViewModel {
        NewMessageComposeViewModel(
            currentUserId: currentUserId,
            repository: messagingRepository,
            sendMessageUseCase: sendMessageUseCase,
            friendsProvider: { [fetchMyFriendsUseCase] in
                try await fetchMyFriendsUseCase.execute()
            },
            groupsProvider: { [fetchMyGroupsUseCase] in
                try await fetchMyGroupsUseCase.execute()
            },
            searchUsersProvider: { [searchUsersUseCase] query in
                let results = try await searchUsersUseCase.execute(query: query, page: 0, size: 20)
                return results.map(\.user)
            },
            uploadImage: { [weak self] data, mimeType in
                guard let self else { throw URLError(.cancelled) }
                let upload = try await self.uploadCommentAttachment(data: data, mimeType: mimeType)
                return MessageImageAttachment(
                    mediaId: upload.id,
                    url: upload.url,
                    thumbnailURL: upload.thumbnailURL
                )
            }
        )
    }

    func makeChatThreadViewModelFactory(currentUserId: UUID) -> ChatThreadViewModelFactory {
        ChatThreadViewModelFactory(
            currentUserId: currentUserId,
            fetchMessagesUseCase: fetchMessagesUseCase,
            sendMessageUseCase: sendMessageUseCase,
            reactToMessageUseCase: reactToMessageUseCase,
            repository: messagingRepository,
            uploadImage: { [weak self] data, mimeType in
                guard let self else { throw URLError(.cancelled) }
                let upload = try await self.uploadCommentAttachment(data: data, mimeType: mimeType)
                return MessageImageAttachment(
                    mediaId: upload.id,
                    url: upload.url,
                    thumbnailURL: upload.thumbnailURL
                )
            },
            wsClient: messagingWebSocketClient
        )
    }

    func makeChatPeerRelationshipActions() -> ChatPeerRelationshipActions {
        let fetchProfile = fetchUserProfileUseCase
        let block = blockUserUseCase
        let unblock = unblockUserUseCase
        let remove = removeFriendUseCase
        let add = addFriendUseCase
        let fetchIncoming = fetchIncomingFriendRequestsUseCase
        let accept = acceptFriendRequestUseCase

        return ChatPeerRelationshipActions(
            fetchStatus: { userId in
                guard let profile = try? await fetchProfile.execute(userId: userId) else {
                    return .unknown
                }
                switch profile.friendStatus {
                case .friends: return .friends
                case .blocked: return .blocked
                case .none: return .stranger
                case .requestSent: return .requestSent
                case .requestReceived: return .requestReceived
                }
            },
            blockUser: { try await block.execute(userId: $0) },
            unblockUser: { try await unblock.execute(userId: $0) },
            removeFriend: { try await remove.execute(friendUserId: $0) },
            addFriend: { userId in
                let profile = try await fetchProfile.execute(userId: userId)
                _ = try await add.execute(username: profile.user.username, message: nil)
            },
            acceptFriendRequest: { userId in
                let incoming = try await fetchIncoming.executeAll()
                guard let request = incoming.first(where: { $0.requester.id == userId }) else { return }
                try await accept.execute(requestId: request.id)
            }
        )
    }

    func makeChatGroupManagementActions() -> ChatGroupManagementActions {
        let fetchMembers = fetchGroupMembersUseCase
        let uploadAvatar = uploadGroupAvatarUseCase
        let updateAvatar = updateGroupAvatarUseCase

        return ChatGroupManagementActions(
            fetchMembers: { groupId in
                let members = try await fetchMembers.execute(groupId: groupId, status: "ACTIVE")
                return members.map { member in
                    GroupChatMember(
                        id: member.id,
                        userId: member.userId,
                        username: member.username,
                        displayName: member.displayName,
                        avatarURL: member.avatarURL,
                        isOwner: member.isOwner
                    )
                }
            },
            updateGroupAvatar: { groupId, imageData in
                let upload = try await uploadAvatar.execute(imageData: imageData, groupId: groupId)
                let updated = try await updateAvatar.execute(
                    groupId: groupId,
                    avatarURL: upload.url.absoluteString
                )
                return updated.avatarURL?.absoluteString ?? upload.url.absoluteString
            }
        )
    }

    func getOrCreateConversationId(friendUserId: UUID) async -> UUID? {
        do {
            let conversation = try await messagingRepository.getOrCreateConversation(friendUserId: friendUserId)
            return conversation.id
        } catch {
            return nil
        }
    }

    // MARK: - Tab ViewModels (survive tab switches)

    lazy var feedViewModel: FeedViewModel = makeFeedViewModel()

    lazy var photoAlbumViewModel: PhotoAlbumViewModel = makePhotoAlbumViewModel()
    lazy var streakViewModel: StreakViewModel = makeStreakViewModel()

    lazy var notificationListViewModel: NotificationListViewModel = makeNotificationListViewModel()

    lazy var expenseListViewModel: ExpenseListViewModel = makeExpenseListViewModel()

    lazy var conversationListViewModel: ConversationListViewModel = makeConversationListViewModel()

    lazy var createGroupConversationViewModel: CreateGroupConversationViewModel = {
        CreateGroupConversationViewModel(
            createGroupUseCase: CreateGroupConversationUseCase(repository: messagingRepository)
        )
    }()

    func openMessagingGroupChat(
        group: Group,
        invitedMemberIds: [UUID],
        conversationListViewModel: ConversationListViewModel,
        onOpen: @escaping (Conversation) -> Void
    ) async {
        guard !invitedMemberIds.isEmpty else {
            conversationListViewModel.startConversationError = languageService.text(
                .messagingGroupChatRequiresMembers
            )
            return
        }

        do {
            let conversation = try await CreateGroupConversationUseCase(
                repository: messagingRepository
            ).execute(
                name: group.name,
                avatarUrl: group.avatarURL?.absoluteString,
                memberUserIds: invitedMemberIds,
                groupId: group.id
            )
            onOpen(conversation)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "openMessagingGroupChat"])
            conversationListViewModel.startConversationError = error.localizedDescription
        }
    }

    func resetTabViewModels() {
        messagingWebSocketClient.disconnect()
        feedViewModel = makeFeedViewModel()
        photoAlbumViewModel = makePhotoAlbumViewModel()
        streakViewModel = makeStreakViewModel()
        notificationListViewModel = makeNotificationListViewModel()
        expenseListViewModel = makeExpenseListViewModel()
        conversationListViewModel = makeConversationListViewModel()
    }

    private func makePhotoAlbumViewModel() -> PhotoAlbumViewModel {
        PhotoAlbumViewModel(fetchPhotoAlbumUseCase: fetchPhotoAlbumUseCase)
    }

    private func makeStreakViewModel() -> StreakViewModel {
        StreakViewModel(
            fetchStreakUseCase: fetchStreakUseCase,
            onStreakUpdated: { [weak self] summary in
                self?.widgetSyncBridge.syncStreak(summary)
            }
        )
    }

    private func makeFeedViewModel() -> FeedViewModel {
        FeedViewModel(
            fetchFeedUseCase: fetchFeedUseCase,
            fetchPostUseCase: fetchPostUseCase,
            reactToPostUseCase: reactToPostUseCase,
            deletePostUseCase: deletePostUseCase,
            addCommentUseCase: addCommentUseCase,
            sendBillReminderUseCase: sendBillReminderUseCase,
            submitPaymentEvidenceUseCase: submitPaymentEvidenceUseCase,
            approvePaymentEvidenceUseCase: approvePaymentEvidenceUseCase,
            rejectPaymentEvidenceUseCase: rejectPaymentEvidenceUseCase,
            createPostUseCase: createPostUseCase,
            onFeedLoaded: { [weak self] posts, userId in
                await self?.widgetSyncBridge.syncFeed(posts: posts, currentUserId: userId)
            }
        )
    }

    private func makeExpenseListViewModel() -> ExpenseListViewModel {
        ExpenseListViewModel(
            fetchExpensesUseCase: fetchExpensesUseCase,
            fetchDebtSummaryUseCase: fetchDebtSummaryUseCase,
            onBadgeCountsChanged: { [weak self] in
                await self?.badgeCountService.refresh()
            },
            onDataLoaded: { [weak self] debts, expenses, userId in
                await self?.widgetSyncBridge.syncExpenses(
                    debts: debts,
                    expenses: expenses,
                    group: nil,
                    currentUserId: userId
                )
            }
        )
    }

    private func makeConversationListViewModel() -> ConversationListViewModel {
        ConversationListViewModel(
            fetchConversationsUseCase: fetchConversationsUseCase,
            searchProvider: MessagingSearchAdapter(
                searchUsersUseCase: searchUsersUseCase,
                messagingRepository: messagingRepository
            ),
            repository: messagingRepository,
            wsClient: messagingWebSocketClient,
            onInboxLoaded: { [weak self] conversations, unreadCount in
                self?.widgetSyncBridge.syncConversations(conversations, totalUnreadCount: unreadCount)
            }
        )
    }

    private func makeNotificationListViewModel() -> NotificationListViewModel {
        NotificationListViewModel(
            fetchNotificationsUseCase: fetchNotificationsUseCase,
            markReadUseCase: markNotificationReadUseCase,
            markClickedUseCase: markNotificationClickedUseCase,
            onBadgeCountsChanged: { [weak self] in
                await self?.badgeCountService.refresh()
            }
        )
    }

    // MARK: - Init

    private init() {
        let tokenProvider = InMemoryTokenProvider()
        self.tokenProvider = tokenProvider
        self.keychainService = KeychainService()
        self.userDefaultsService = UserDefaultsService()
        self.languageService = LanguageService(userDefaults: userDefaultsService)
        self.sessionManager = SessionManager()

        let refreshCoordinator = TokenRefreshCoordinator()
        let apiClient = APIClient(
            tokenProvider: tokenProvider,
            tokenRefresher: refreshCoordinator,
            localeProvider: languageService
        )
        let authRepository = AuthRepository(
            apiClient: apiClient,
            keychainService: keychainService,
            tokenProvider: tokenProvider
        )
        let refreshTokenUseCase = RefreshTokenUseCase(
            repository: authRepository,
            sessionManager: sessionManager,
            tokenProvider: tokenProvider
        )
        refreshCoordinator.configure { [refreshTokenUseCase] in
            try await refreshTokenUseCase.refreshSession()
        }

        self.apiClient = apiClient
        self.authRepository = authRepository
        self.refreshTokenUseCase = refreshTokenUseCase
        self.restoreSessionUseCase = RestoreSessionUseCase(
            repository: authRepository,
            sessionManager: sessionManager,
            keychainService: keychainService,
            tokenProvider: tokenProvider,
            refreshTokenUseCase: refreshTokenUseCase
        )
    }
}
