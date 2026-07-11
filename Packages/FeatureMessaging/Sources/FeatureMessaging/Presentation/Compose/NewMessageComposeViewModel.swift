import Foundation
import Common
import SplickDomain

@MainActor
public final class NewMessageComposeViewModel: ObservableObject {
    @Published public private(set) var friends: [UserSummary] = []
    @Published public private(set) var groups: [Group] = []
    @Published public private(set) var remoteSearchUsers: [UserSummary] = []
    @Published public var searchQuery = ""
    @Published public var messageBody = ""
    @Published public var attachmentDrafts: [CommentAttachmentDraft] = []
    @Published public var selectedUsers: [UserSummary] = []
    @Published public var selectedGroup: Group?
    @Published public private(set) var isLoadingDirectory = false
    @Published public private(set) var isSearching = false
    @Published public private(set) var isSending = false
    @Published public var errorMessage: String?

    private let currentUserId: UUID
    private let repository: MessagingRepositoryProtocol
    private let sendMessageUseCase: SendMessageUseCase
    private let friendsProvider: () async throws -> [UserSummary]
    private let groupsProvider: () async throws -> [Group]
    private let searchUsersProvider: (_ query: String) async throws -> [UserSummary]
    private let uploadImage: (Data, String) async throws -> MessageImageAttachment
    private var searchTask: Task<Void, Never>?

    public init(
        currentUserId: UUID,
        repository: MessagingRepositoryProtocol,
        sendMessageUseCase: SendMessageUseCase,
        friendsProvider: @escaping () async throws -> [UserSummary],
        groupsProvider: @escaping () async throws -> [Group],
        searchUsersProvider: @escaping (_ query: String) async throws -> [UserSummary],
        uploadImage: @escaping (Data, String) async throws -> MessageImageAttachment
    ) {
        self.currentUserId = currentUserId
        self.repository = repository
        self.sendMessageUseCase = sendMessageUseCase
        self.friendsProvider = friendsProvider
        self.groupsProvider = groupsProvider
        self.searchUsersProvider = searchUsersProvider
        self.uploadImage = uploadImage
    }

    public var canSend: Bool {
        hasRecipients && hasMessageContent && !isSending && !isProcessingAttachments && !hasFailedAttachments
    }

    public var hasRecipients: Bool {
        selectedGroup != nil || !selectedUsers.isEmpty
    }

    private var hasMessageContent: Bool {
        !messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || attachmentDrafts.contains { $0.phase == .ready && $0.submission != nil }
    }

    public var isProcessingAttachments: Bool {
        attachmentDrafts.contains { $0.phase == .loading }
    }

    public var hasFailedAttachments: Bool {
        attachmentDrafts.contains {
            if case .failed = $0.phase { return true }
            return false
        }
    }

    public var filteredFriends: [UserSummary] {
        guard let query = normalizedQuery else { return friends }
        return friends.filter { matchesQuery($0, query: query) }
    }

    public var filteredGroups: [Group] {
        guard let query = normalizedQuery else { return groups }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(query)
                || group.inviteCode.localizedCaseInsensitiveContains(query)
        }
    }

    public var filteredRemoteUsers: [UserSummary] {
        remoteSearchUsers.filter { user in
            user.id != currentUserId
                && !friends.contains(where: { $0.id == user.id })
                && !selectedUsers.contains(where: { $0.id == user.id })
        }
    }

    public func loadDirectoryIfNeeded() async {
        guard friends.isEmpty, groups.isEmpty, !isLoadingDirectory else { return }
        isLoadingDirectory = true
        defer { isLoadingDirectory = false }

        async let friendsTask = friendsProvider()
        async let groupsTask = groupsProvider()
        friends = (try? await friendsTask) ?? []
        groups = (try? await groupsTask) ?? []
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

    public func toggleUser(_ user: UserSummary) {
        guard user.id != currentUserId else { return }
        selectedGroup = nil
        if let index = selectedUsers.firstIndex(where: { $0.id == user.id }) {
            selectedUsers.remove(at: index)
        } else {
            selectedUsers.append(user)
        }
    }

    public func selectGroup(_ group: Group) {
        if selectedGroup?.id == group.id {
            selectedGroup = nil
        } else {
            selectedGroup = group
            selectedUsers = []
        }
    }

    public func removeUser(_ user: UserSummary) {
        selectedUsers.removeAll { $0.id == user.id }
    }

    public func removeSelectedGroup() {
        selectedGroup = nil
    }

    public func isUserSelected(_ user: UserSummary) -> Bool {
        selectedUsers.contains(where: { $0.id == user.id })
    }

    public func send(submissions: [CommentSubmissionAttachment]) async -> Conversation? {
        let body = messageBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasRecipients, !isSending else { return nil }
        guard !body.isEmpty || !submissions.isEmpty else { return nil }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let conversation = try await resolveConversation()
            let attachments = try await resolveImageAttachments(from: submissions)
            let imageSubmissions = submissions.filter { $0.kind == .image }
            if !imageSubmissions.isEmpty, attachments.isEmpty {
                errorMessage = "Không tải được ảnh. Vui lòng thử lại."
                return nil
            }
            _ = try await sendMessageUseCase.execute(
                conversationId: conversation.id,
                body: body,
                clientMessageId: UUID(),
                replyToMessageId: nil,
                imageAttachments: attachments
            )

            messageBody = ""
            attachmentDrafts = []
            return conversation
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func resolveImageAttachments(
        from submissions: [CommentSubmissionAttachment]
    ) async throws -> [MessageImageAttachment] {
        var attachments: [MessageImageAttachment] = []
        attachments.reserveCapacity(submissions.count)

        for submission in submissions where submission.kind == .image {
            if let attachment = MessageAttachmentMapper.messageImage(from: submission) {
                attachments.append(attachment)
            } else if let data = submission.data {
                attachments.append(try await uploadImage(data, submission.mimeType ?? "image/jpeg"))
            }
        }

        return attachments
    }

    private var normalizedQuery: String? {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolveConversation() async throws -> Conversation {
        if let group = selectedGroup {
            let memberIds = group.members
                .map(\.id)
                .filter { $0 != currentUserId }
            return try await repository.createGroup(
                name: group.name,
                avatarUrl: group.avatarURL?.absoluteString,
                memberUserIds: memberIds,
                groupId: group.id
            )
        }

        if selectedUsers.count == 1, let user = selectedUsers.first {
            return try await repository.getOrCreateConversation(friendUserId: user.id)
        }

        let name = selectedUsers
            .map(shortDisplayName)
            .joined(separator: ", ")
        let memberIds = selectedUsers.map(\.id)
        return try await repository.createGroup(
            name: name.isEmpty ? "Nhóm chat" : name,
            avatarUrl: nil,
            memberUserIds: memberIds
        )
    }

    private func matchesQuery(_ user: UserSummary, query: String) -> Bool {
        user.displayName.localizedCaseInsensitiveContains(query)
            || user.username.localizedCaseInsensitiveContains(query)
    }

    private func shortDisplayName(_ user: UserSummary) -> String {
        let trimmed = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return user.username }
        return trimmed.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? trimmed
    }
}
