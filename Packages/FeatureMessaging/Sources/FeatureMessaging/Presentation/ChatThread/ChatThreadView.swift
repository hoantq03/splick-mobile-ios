import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain
import Storage

public struct ChatThreadView: View {
    @ObservedObject private var viewModel: ChatThreadViewModel
    @ObservedObject private var relationshipViewModel: ChatPeerRelationshipViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.openUserProfile) private var openUserProfile
    @Environment(\.currentUserSummary) private var currentUserSummary
    @FocusState private var isInputFocused: Bool
    @State private var inputText: String = ""

    private let currentUserId: UUID
    private let peer: ConversationPeer?
    private let navigationTitle: String
    private let conversation: Conversation?
    private let repository: MessagingRepositoryProtocol?

    @State private var showsGroupInfo = false

    public init(
        viewModel: ChatThreadViewModel,
        relationshipViewModel: ChatPeerRelationshipViewModel,
        currentUserId: UUID,
        peer: ConversationPeer? = nil,
        navigationTitle: String = "",
        conversation: Conversation? = nil,
        repository: MessagingRepositoryProtocol? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._relationshipViewModel = ObservedObject(wrappedValue: relationshipViewModel)
        self.currentUserId = currentUserId
        self.peer = peer
        self.navigationTitle = navigationTitle
        self.conversation = conversation
        self.repository = repository
    }

    public var body: some View {
        VStack(spacing: 0) {
            if relationshipViewModel.showsAddFriendBanner {
                addFriendBanner
                Divider()
            }
            messageArea
            Divider()
            bottomBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: openChatHeader) {
                    HStack(spacing: SplickTheme.Spacing.xs) {
                        AvatarView(
                            imageURL: (conversation?.isGroup == true
                                ? conversation?.groupAvatarUrl
                                : peer?.avatarUrl)?.flatMap(URL.init(string:)),
                            name: navigationTitle,
                            size: .small
                        )
                        Text(navigationTitle)
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(navigationTitle)
                .disabled(!canOpenChatHeader)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if conversation?.isGroup == true, repository != nil {
                    Button {
                        showsGroupInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                } else if relationshipViewModel.isActive, !relationshipViewModel.isBlocked {
                    directChatOptionsMenu
                }
            }
        }
        .sheet(isPresented: $showsGroupInfo) {
            if let conversation, let repository {
                GroupInfoView(
                    conversation: conversation,
                    repository: repository,
                    currentUserId: currentUserId,
                    onUpdated: {}
                )
            }
        }
        .confirmationDialog(
            languageService.text(.friendsRemoveFriendConfirmTitle),
            isPresented: $relationshipViewModel.showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.friendsRemoveFriendConfirmAction), role: .destructive) {
                Task { await relationshipViewModel.removeFriend() }
            }
        }
        .confirmationDialog(
            languageService.text(.friendsBlockConfirmTitle),
            isPresented: $relationshipViewModel.showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.friendsBlockConfirmAction), role: .destructive) {
                Task { await relationshipViewModel.blockUser() }
            }
        }
        .onChange(of: relationshipViewModel.isBlocked) { isBlocked in
            guard isBlocked else { return }
            inputText = ""
            isInputFocused = false
        }
        .onAppear { tabBarScrollState?.hide(flushToBottom: true) }
        .onDisappear { tabBarScrollState?.show() }
        .task {
            async let messages: Void = viewModel.loadIfNeeded()
            async let relationship: Void = relationshipViewModel.loadIfNeeded()
            _ = await (messages, relationship)
        }
    }

    private var directChatOptionsMenu: some View {
        Menu {
            if relationshipViewModel.canRemoveFriend {
                Button(role: .destructive) {
                    relationshipViewModel.showRemoveConfirm = true
                } label: {
                    Label(
                        languageService.text(.friendsRemoveFriend),
                        systemImage: "person.badge.minus"
                    )
                }
            }
            Button(role: .destructive) {
                relationshipViewModel.showBlockConfirm = true
            } label: {
                Label(
                    languageService.text(.friendsBlockUser),
                    systemImage: "hand.raised.fill"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(languageService.text(.messagingChatMoreAccessibility))
        .disabled(relationshipViewModel.isProcessing)
    }

    private var addFriendBanner: some View {
        VStack(spacing: SplickTheme.Spacing.xxs) {
            Text(addFriendBannerMessage)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            if let bannerActionTitle = addFriendBannerActionTitle {
                Button(bannerActionTitle) {
                    Task { await performAddFriendBannerAction() }
                }
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .disabled(relationshipViewModel.isProcessing)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
    }

    private var addFriendBannerMessage: String {
        switch relationshipViewModel.status {
        case .requestSent:
            return languageService.text(.messagingChatRequestSentBanner)
        case .requestReceived:
            return languageService.text(.messagingChatRequestReceivedBanner)
        default:
            return languageService.text(.messagingChatNotFriendsBanner)
        }
    }

    private var addFriendBannerActionTitle: String? {
        switch relationshipViewModel.status {
        case .stranger:
            return languageService.text(.feedProfileAddFriend)
        case .requestReceived:
            return languageService.text(.friendsAccept)
        case .requestSent:
            return nil
        default:
            return nil
        }
    }

    private func performAddFriendBannerAction() async {
        switch relationshipViewModel.status {
        case .stranger:
            await relationshipViewModel.addFriend()
        case .requestReceived:
            await relationshipViewModel.acceptFriendRequest()
        default:
            break
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !relationshipViewModel.isActive {
            inputBar
        } else if relationshipViewModel.isBlocked {
            blockedFooter
        } else if relationshipViewModel.status == .unknown {
            relationshipStatusPlaceholder
        } else {
            inputBar
        }
    }

    private var relationshipStatusPlaceholder: some View {
        Color.clear
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.background)
    }

    private var blockedFooter: some View {
        VStack(spacing: SplickTheme.Spacing.xxs) {
            Text(languageService.text(.messagingChatBlockedMessage))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                Task { await relationshipViewModel.unblockUser() }
            } label: {
                Text(languageService.text(.friendsUnblock))
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .disabled(relationshipViewModel.isProcessing)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.background)
    }

    private var canOpenChatHeader: Bool {
        if conversation?.isGroup == true {
            return repository != nil
        }
        return peer != nil && openUserProfile != nil
    }

    private func openChatHeader() {
        if conversation?.isGroup == true {
            guard repository != nil else { return }
            showsGroupInfo = true
            return
        }
        guard let peer, let openUserProfile else { return }
        let user = UserSummary(
            id: peer.userId,
            username: peer.username,
            displayName: peer.displayTitle,
            avatarURL: peer.avatarUrl.flatMap(URL.init(string:))
        )
        guard user.id != currentUserSummary?.id else { return }
        openUserProfile(user)
    }

    @ViewBuilder
    private var messageArea: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: languageService.text(.messagingChatLoading))
        case .loaded(let messages) where messages.isEmpty:
            EmptyStateView(
                icon: "bubble.left",
                title: languageService.text(.messagingChatEmptyTitle),
                message: languageService.text(.messagingChatEmptyMessage)
            )
        case .loaded(let messages):
            ChatMessageListView(
                viewModel: viewModel,
                messages: messages,
                currentUserId: currentUserId
            )
        case .failed(let error):
            ErrorView(message: error) {
                Task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            TextField(languageService.text(.messagingInputPlaceholder), text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .font(SplickTheme.Typography.body)
                .focused($isInputFocused)
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.xs)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                let text = inputText
                inputText = ""
                Task { await viewModel.send(body: text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? SplickTheme.Colors.textTertiary
                        : SplickTheme.Colors.primaryGradientStart)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.background)
    }
}
