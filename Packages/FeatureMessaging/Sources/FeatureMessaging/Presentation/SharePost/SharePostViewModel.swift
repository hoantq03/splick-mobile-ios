import Foundation
import Common
import Localization
import SplickDomain
import SwiftUI

@MainActor
public final class SharePostViewModel: ObservableObject {
    @Published public private(set) var recipients: [SharePostRecipient] = []
    @Published public private(set) var remoteSearchUsers: [UserSummary] = []
    @Published public var searchQuery = ""
    @Published public var messageNote = ""
    @Published public private(set) var selectedTargets: Set<SharePostChatTarget> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSearching = false
    @Published public private(set) var isSending = false
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?

    public let shareURL: URL

    private let currentUserId: UUID?
    private let shareUseCase: SharePostToChatUseCase
    private let fetchConversationsUseCase: FetchConversationsUseCase
    private let friendsProvider: () async throws -> [UserSummary]
    private let searchUsersProvider: (_ query: String) async throws -> [UserSummary]
    private let languageService: LanguageService
    private var searchTask: Task<Void, Never>?

    public init(
        shareURL: URL,
        currentUserId: UUID?,
        shareUseCase: SharePostToChatUseCase,
        fetchConversationsUseCase: FetchConversationsUseCase,
        friendsProvider: @escaping () async throws -> [UserSummary],
        searchUsersProvider: @escaping (_ query: String) async throws -> [UserSummary],
        languageService: LanguageService
    ) {
        self.shareURL = shareURL
        self.currentUserId = currentUserId
        self.shareUseCase = shareUseCase
        self.fetchConversationsUseCase = fetchConversationsUseCase
        self.friendsProvider = friendsProvider
        self.searchUsersProvider = searchUsersProvider
        self.languageService = languageService
    }

    public var canSend: Bool {
        !selectedTargets.isEmpty && !isSending
    }

    public var visibleRecipients: [SharePostRecipient] {
        guard let query = normalizedQuery else { return recipients }
        return recipients.filter { recipient in
            recipient.title.localizedCaseInsensitiveContains(query)
                || (recipient.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    public var visibleRemoteUsers: [UserSummary] {
        remoteSearchUsers.filter { user in
            user.id != currentUserId
                && !recipients.contains(where: { recipient in
                    if case .friend(let existing) = recipient.kind {
                        return existing.id == user.id
                    }
                    if case .conversation(let conversation) = recipient.kind {
                        return conversation.peer?.userId == user.id
                    }
                    return false
                })
        }
    }

    public func loadDirectoryIfNeeded() async {
        guard recipients.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let conversationsTask = fetchConversationsUseCase.execute(
            query: ConversationInboxQuery(page: 0, limit: 30)
        )
        async let friendsTask = friendsProvider()

        let conversations = (try? await conversationsTask)?.items ?? []
        let friends = (try? await friendsTask) ?? []

        let peerIds = Set(conversations.compactMap(\.peer?.userId))
        var merged: [SharePostRecipient] = conversations
            .filter { !$0.isRemovedFromGroup }
            .map { SharePostRecipient(kind: .conversation($0)) }

        for friend in friends where friend.id != currentUserId && !peerIds.contains(friend.id) {
            merged.append(SharePostRecipient(kind: .friend(friend)))
        }
        recipients = merged
    }

    public func onSearchQueryChanged(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            remoteSearchUsers = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                let users = try await searchUsersProvider(trimmed)
                guard !Task.isCancelled else { return }
                remoteSearchUsers = users
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                remoteSearchUsers = []
                isSearching = false
            }
        }
    }

    public func toggle(_ recipient: SharePostRecipient) {
        toggle(target: recipient.target)
    }

    public func toggleRemoteUser(_ user: UserSummary) {
        toggle(target: .friend(user.id))
    }

    public func isSelected(_ recipient: SharePostRecipient) -> Bool {
        selectedTargets.contains(recipient.target)
    }

    public func isRemoteUserSelected(_ user: UserSummary) -> Bool {
        selectedTargets.contains(.friend(user.id))
    }

    public func send() async -> Bool {
        guard canSend else { return false }
        isSending = true
        errorMessage = nil
        statusMessage = nil
        defer { isSending = false }

        let outcome = await shareUseCase.execute(
            shareURL: shareURL,
            note: messageNote,
            targets: Array(selectedTargets)
        )
        if outcome.failedCount > 0, outcome.didSendAny {
            errorMessage = languageService.format(
                .feedShareToChatPartialFailure,
                outcome.sentCount,
                outcome.failedCount
            )
            return false
        }
        if !outcome.didSendAny {
            errorMessage = languageService.text(.feedShareToChatSendFailed)
            return false
        }
        statusMessage = languageService.text(.feedShareToChatSent)
        return true
    }

    public func copyLinkSucceeded() {
        statusMessage = languageService.text(.feedShareToChatCopied)
    }

    private func toggle(target: SharePostChatTarget) {
        if selectedTargets.contains(target) {
            selectedTargets.remove(target)
        } else {
            selectedTargets.insert(target)
        }
    }

    private var normalizedQuery: String? {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
