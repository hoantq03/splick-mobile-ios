import Foundation
import Combine
import Common
import Localization
import SplickDomain
import SwiftUI
import UIKit

@MainActor
public final class ChatThreadViewModel: ObservableObject {

    public enum State {
        case idle
        case loading
        case loaded([ChatMessage])
        case failed(String)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var isSending = false
    @Published public var attachmentDrafts: [CommentAttachmentDraft] = []
    @Published public private(set) var scrollToBottomToken = 0
    @Published public private(set) var scrollToMessageToken = 0
    @Published public private(set) var highlightedMessageId: UUID?
    @Published public private(set) var newlySentMessageIds: Set<UUID> = []
    @Published public var replyDraft: MessageReplyDraft?
    @Published public private(set) var hasMoreMessages = false
    @Published public private(set) var isLoadingOlder = false
    /// After older messages are prepended, the list scrolls to this client id to avoid jump.
    @Published public private(set) var prependAnchorMessageId: UUID?
    /// Set by the message list when the bottom anchor is visible.
    @Published public var isNearBottom = false
    @Published public private(set) var threadSearchHits: [MessageSearchHit] = []
    @Published public private(set) var threadSearchState: LoadingState<[MessageSearchHit]> = .idle
    @Published public private(set) var activeThreadSearchQuery = ""
    @Published public private(set) var typingUserIds: [UUID] = []
    @Published public private(set) var leftAt: Date?
    /// True when the current user is OWNER/ADMIN in this group (loaded asynchronously).
    @Published public private(set) var isGroupOwner = false

    private static let maxPagesForMessageLookup = 10
    private static let pageSize = 30
    private static let highlightDuration: Duration = .seconds(2)
    private static let markReadDebounce: Duration = .milliseconds(500)

    private var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public let conversationId: UUID
    public let currentUserId: UUID
    private let highlightMessageId: UUID?
    private let fetchMessagesUseCase: FetchMessagesUseCase
    private let sendMessageUseCase: SendMessageUseCase
    private let reactToMessageUseCase: ReactToMessageUseCaseProtocol
    private let repository: MessagingRepositoryProtocol
    private let uploadImage: (Data, String) async throws -> MessageImageAttachment
    private let onConversationRead: ((UUID) async -> Void)?
    private let wsClient: MessagingWebSocketClient
    private let languageService: LanguageService
    private let messageCache: MessageThreadCache?
    private let pendingMessageStore: PendingMessageStore
    private let networkPathMonitor: NetworkPathMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var highlightClearTask: Task<Void, Never>?
    private var markReadTask: Task<Void, Never>?
    private var gapFillTask: Task<Void, Never>?
    private var floatSwayByMessageId: [UUID: CGFloat] = [:]
    private var pendingBodiesByClientId: [UUID: String] = [:]
    private var pendingAttachmentsByClientId: [UUID: [MessageImageAttachment]] = [:]
    private var pendingReplyByClientId: [UUID: UUID?] = [:]
    /// Highest page index successfully loaded (API page 0 = newest).
    private var highestLoadedPage = 0
    private var maxSequenceNo: Int64 = 0
    private var lastMarkedReadMessageId: UUID?
    private var pathMonitorHandlerId: UUID?
    private var foregroundObserver: NSObjectProtocol?
    private var threadSearchTask: Task<Void, Never>?
    private var remoteTypingTimeouts: [UUID: Task<Void, Never>] = [:]
    private var localTypingIdleTask: Task<Void, Never>?
    private var lastTypingStartSentAt: Date?
    private var isLocallyTyping = false

    public init(
        conversationId: UUID,
        currentUserId: UUID,
        highlightMessageId: UUID? = nil,
        fetchMessagesUseCase: FetchMessagesUseCase,
        sendMessageUseCase: SendMessageUseCase,
        reactToMessageUseCase: ReactToMessageUseCaseProtocol,
        repository: MessagingRepositoryProtocol,
        uploadImage: @escaping (Data, String) async throws -> MessageImageAttachment,
        wsClient: MessagingWebSocketClient,
        languageService: LanguageService,
        messageCache: MessageThreadCache? = nil,
        pendingMessageStore: PendingMessageStore? = nil,
        networkPathMonitor: NetworkPathMonitor? = nil,
        onConversationRead: ((UUID) async -> Void)? = nil,
        leftAt: Date? = nil
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.highlightMessageId = highlightMessageId
        self.fetchMessagesUseCase = fetchMessagesUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.reactToMessageUseCase = reactToMessageUseCase
        self.repository = repository
        self.uploadImage = uploadImage
        self.wsClient = wsClient
        self.languageService = languageService
        self.messageCache = messageCache
        self.pendingMessageStore = pendingMessageStore ?? PendingMessageStore()
        self.networkPathMonitor = networkPathMonitor
        self.onConversationRead = onConversationRead
        self.leftAt = leftAt
        bindWsEvents()
        bindNetworkRetry()
        bindForegroundGapFill()
        _ = applyCachedThreadIfAvailable()
    }

    public var isRemovedFromGroup: Bool { leftAt != nil }

    public func groupThreadCapabilities(isGroup: Bool) -> GroupChatThreadCapabilities {
        GroupChatThreadCapabilities.resolve(
            isGroup: isGroup,
            isRemoved: isRemovedFromGroup,
            isOwner: isGroupOwner
        )
    }

    /// Loads whether the current user is group owner/admin. No-op for direct chats or removed viewers.
    public func refreshGroupViewerRole(isGroup: Bool) async {
        guard isGroup else {
            isGroupOwner = false
            return
        }
        if isRemovedFromGroup {
            isGroupOwner = false
            return
        }
        let members = (try? await repository.listGroupMembers(groupId: conversationId)) ?? []
        isGroupOwner = members.contains { $0.userId == currentUserId && $0.isOwner }
    }

    public var messages: [ChatMessage] {
        if case .loaded(let msgs) = state { return visibleMessages(msgs) }
        return []
    }

    public var isInitialLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public func clearCachedThread() {
        messageCache?.remove(conversationId: conversationId)
    }

    public func floatSway(for messageId: UUID) -> CGFloat {
        floatSwayByMessageId[messageId] ?? 0
    }

    public func clearPrependAnchor() {
        prependAnchorMessageId = nil
    }

    public func loadIfNeeded() async {
        guard !isLoading else { return }
        await load()
    }

    public func onComposerTextChanged(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            stopLocalTyping()
            return
        }
        let now = Date()
        let shouldSendStart = !isLocallyTyping
            || now.timeIntervalSince(lastTypingStartSentAt ?? .distantPast)
            >= MessagingTypingTiming.startRefresh
        if shouldSendStart {
            wsClient.sendTyping(conversationId: conversationId, isTyping: true)
            lastTypingStartSentAt = now
            isLocallyTyping = true
        }
        localTypingIdleTask?.cancel()
        localTypingIdleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(MessagingTypingTiming.idleStop))
            guard !Task.isCancelled else { return }
            self?.stopLocalTyping()
        }
    }

    public func stopLocalTyping() {
        localTypingIdleTask?.cancel()
        localTypingIdleTask = nil
        guard isLocallyTyping else { return }
        isLocallyTyping = false
        lastTypingStartSentAt = nil
        wsClient.sendTyping(conversationId: conversationId, isTyping: false)
    }

    public func onThreadSearchQueryChanged(_ query: String) {
        threadSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            threadSearchHits = []
            threadSearchState = .idle
            activeThreadSearchQuery = ""
            return
        }
        if threadSearchHits.isEmpty {
            threadSearchState = .loading
        }
        threadSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                let hits = try await repository.searchMessages(
                    query: trimmed,
                    page: 0,
                    limit: 30,
                    conversationId: conversationId
                )
                guard !Task.isCancelled else { return }
                threadSearchHits = hits
                threadSearchState = .loaded(hits)
                activeThreadSearchQuery = trimmed
            } catch {
                guard !Task.isCancelled else { return }
                threadSearchHits = []
                threadSearchState = .failed(languageService.localizedMessage(for: error))
                activeThreadSearchQuery = ""
                Log.error(error, category: .network, metadata: ["action": "searchThreadMessages"])
            }
        }
    }

    public func clearThreadSearch() {
        threadSearchTask?.cancel()
        threadSearchHits = []
        threadSearchState = .idle
        activeThreadSearchQuery = ""
    }

    public func revealSearchedMessage(id: UUID) async {
        if messages.contains(where: { $0.id == id }) {
            activateHighlight(for: id)
            requestScrollToMessage(id)
            return
        }
        do {
            try await loadUntilMessage(id: id)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "revealSearchedMessage"])
        }
    }

    public func load() async {
        guard !isLoading else { return }

        // Paint cached thread immediately, then reconcile with the network.
        let paintedFromCache = applyCachedThreadIfAvailable()
        if paintedFromCache {
            requestScrollToBottom()
        } else if case .loaded(let existing) = state, !existing.isEmpty {
            // Keep the visible thread while refreshing — avoids a loading flash on push.
        } else {
            state = .loading
        }

        do {
            if let targetId = highlightMessageId {
                try await loadUntilMessage(id: targetId)
            } else {
                let page = try await fetchMessagesUseCase.execute(
                    conversationId: conversationId,
                    page: 0,
                    limit: Self.pageSize
                )
                let sorted = MessageTimelineOrdering.sortedChronologically(Array(page.items.reversed()))
                highestLoadedPage = 0
                hasMoreMessages = page.hasMore
                state = .loaded(sorted)
                recomputeMaxSequenceNo()
                restorePendingMessages()
                persistCache()
                requestScrollToBottom()
                if let lastId = sorted.last?.id {
                    scheduleMarkRead(upToMessageId: lastId, requireNearBottom: false)
                    sendDeliveryAck(for: lastId)
                }
            }
        } catch {
            Log.error(error, category: .network, metadata: ["action": "loadMessages"])
            if case .loaded = state {
                restorePendingMessages()
                return
            }
            state = .failed(languageService.localizedMessage(for: error))
        }
    }

    /// Fetches the next older page when the user scrolls to the top of the thread.
    public func loadOlderMessagesIfNeeded(current message: ChatMessage) async {
        guard hasMoreMessages, !isLoadingOlder, !isLoading else { return }
        guard messages.first?.id == message.id else { return }

        isLoadingOlder = true
        defer { isLoadingOlder = false }

        let nextPage = highestLoadedPage + 1
        let anchorClientId = message.clientMessageId
        let beforeSequence = message.sequenceNo > 0 ? message.sequenceNo : nil

        do {
            let page = try await fetchMessagesUseCase.execute(
                conversationId: conversationId,
                page: nextPage,
                limit: Self.pageSize,
                before: beforeSequence
            )
            let batch = page.items
            guard !batch.isEmpty else {
                hasMoreMessages = false
                persistCache()
                return
            }

            let olderChronological = batch.reversed() as [ChatMessage]
            let existingIds = Set(messages.map(\.id))
            let existingClientIds = Set(messages.map(\.clientMessageId))
            let uniqueOlder = olderChronological.filter {
                !existingIds.contains($0.id) && !existingClientIds.contains($0.clientMessageId)
            }

            guard !uniqueOlder.isEmpty else {
                hasMoreMessages = page.hasMore
                highestLoadedPage = nextPage
                persistCache()
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                state = .loaded(MessageTimelineOrdering.sortedChronologically(uniqueOlder + messages))
                highestLoadedPage = nextPage
                hasMoreMessages = page.hasMore
                prependAnchorMessageId = anchorClientId
            }
            recomputeMaxSequenceNo()
            persistCache()
        } catch {
            Log.error(error, category: .network, metadata: ["action": "loadOlderMessages"])
        }
    }

    public func send(body: String, submissions: [CommentSubmissionAttachment]) async {
        guard !isRemovedFromGroup else { return }
        stopLocalTyping()
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !submissions.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            let attachments = try await resolveImageAttachments(from: submissions)
            let mediaSubmissions = submissions.filter { $0.kind == .image || $0.kind == .gif }
            if !mediaSubmissions.isEmpty, attachments.isEmpty {
                Log.error("Image upload produced no attachments", category: .network)
                return
            }
            let activeReplyDraft = replyDraft
            let replyToMessageId = activeReplyDraft?.messageId
            let clientMessageId = UUID()
            let replyPreview = activeReplyDraft?.replyPreview
            let optimistic = ChatMessage(
                id: clientMessageId,
                conversationId: conversationId,
                senderId: currentUserId,
                body: trimmed,
                clientMessageId: clientMessageId,
                createdAt: Date(),
                deliveryStatus: .sending,
                imageAttachments: attachments,
                replyPreview: replyPreview
            )

            rememberPending(
                clientMessageId: clientMessageId,
                body: trimmed,
                attachments: attachments,
                replyToMessageId: replyToMessageId
            )
            registerFloatAnimation(for: clientMessageId)
            appendMessage(optimistic)

            let sent = try await sendMessageUseCase.execute(
                conversationId: conversationId,
                body: trimmed,
                clientMessageId: clientMessageId,
                imageAttachments: attachments,
                replyToMessageId: replyToMessageId
            )
            replaceMessage(
                matching: clientMessageId,
                with: sent.updating(deliveryStatus: .sent)
            )
            clearPending(clientMessageId: clientMessageId)

            attachmentDrafts = []
            withAnimation(MessageReplyIslandMotion.dismiss) {
                replyDraft = nil
            }
        } catch {
            Log.error(error, category: .network, metadata: ["action": "sendMessage"])
            if case .loaded(let messages) = state,
               let lastOptimistic = messages.last(where: { $0.deliveryStatus == .sending && $0.senderId == currentUserId }) {
                updateDeliveryStatus(for: lastOptimistic.clientMessageId, status: .failed)
                persistFailedPending(clientMessageId: lastOptimistic.clientMessageId)
            }
        }
    }

    public func send(body: String) async {
        await send(body: body, submissions: [])
    }

    public func beginReply(to message: ChatMessage, senderDisplayName: String) {
        guard !isRemovedFromGroup else { return }
        let snippet = replySnippet(from: message)
        withAnimation(MessageReplyIslandMotion.present) {
            replyDraft = MessageReplyDraft(
                messageId: message.id,
                senderId: message.senderId,
                senderDisplayName: senderDisplayName,
                bodySnippet: snippet,
                hasImageAttachment: message.hasImageAttachments
            )
        }
    }

    public func cancelReply() {
        withAnimation(MessageReplyIslandMotion.dismiss) {
            replyDraft = nil
        }
    }

    public func retrySend(messageId: UUID) async {
        guard case .loaded(let messages) = state,
              let message = messages.first(where: { $0.id == messageId }),
              message.deliveryStatus == .failed else { return }

        let body = pendingBodiesByClientId[message.clientMessageId] ?? message.body
        let attachments = pendingAttachmentsByClientId[message.clientMessageId] ?? message.imageAttachments
        let replyToMessageId = pendingReplyByClientId[message.clientMessageId] ?? message.replyPreview?.messageId
        updateDeliveryStatus(for: message.clientMessageId, status: .sending)

        do {
            let sent = try await sendMessageUseCase.execute(
                conversationId: conversationId,
                body: body,
                clientMessageId: message.clientMessageId,
                imageAttachments: attachments,
                replyToMessageId: replyToMessageId
            )
            replaceMessage(
                matching: message.clientMessageId,
                with: sent.updating(deliveryStatus: .sent)
            )
            clearPending(clientMessageId: message.clientMessageId)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "retrySendMessage"])
            updateDeliveryStatus(for: message.clientMessageId, status: .failed)
            persistFailedPending(clientMessageId: message.clientMessageId)
        }
    }

    public func markRead(upToMessageId: UUID) {
        scheduleMarkRead(upToMessageId: upToMessageId, requireNearBottom: false)
    }

    @discardableResult
    public func react(to messageId: UUID, emoji: String) -> String? {
        guard !isRemovedFromGroup else { return nil }
        guard case .loaded(let messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return nil
        }

        let message = messages[index]

        if let existing = message.reactions.first(where: {
            $0.userId == currentUserId && $0.emoji == emoji
        }) {
            let snapshot = message
            removeReaction(messageId: messageId, reactionId: existing.id)
            Task {
                do {
                    try await repository.removeReaction(
                        conversationId: conversationId,
                        messageId: messageId,
                        reactionId: existing.id
                    )
                } catch {
                    updateMessage(at: index, with: snapshot)
                    Log.error(error, category: .network, metadata: ["action": "removeMessageReaction"])
                }
            }
            return nil
        }

        let optimisticId = UUID()
        let reaction = Reaction(id: optimisticId, emoji: emoji, userId: currentUserId)
        updateMessage(at: index, with: message.updating(reactions: message.reactions + [reaction]))

        Task {
            do {
                let serverReaction = try await reactToMessageUseCase.execute(
                    conversationId: conversationId,
                    messageId: messageId,
                    emoji: emoji
                )
                reconcileReaction(messageId: messageId, optimisticId: optimisticId, with: serverReaction)
            } catch {
                removeReaction(messageId: messageId, reactionId: optimisticId)
                Log.error(error, category: .network, metadata: ["action": "reactToMessage"])
            }
        }

        return nil
    }

    // MARK: - Gap fill

    private func gapFillIfNeeded() async {
        guard maxSequenceNo > 0 else { return }
        do {
            let page = try await repository.fetchMessages(
                conversationId: conversationId,
                page: 0,
                limit: Self.pageSize,
                after: maxSequenceNo,
                before: nil
            )
            guard !page.items.isEmpty else { return }
            for message in page.items {
                upsertIncomingMessage(message)
            }
            if isNearBottom, let lastId = messages.last?.id {
                scheduleMarkRead(upToMessageId: lastId)
            }
        } catch {
            Log.error(error, category: .network, metadata: ["action": "gapFillMessages"])
        }
    }

    private func scheduleGapFill() {
        gapFillTask?.cancel()
        gapFillTask = Task { [weak self] in
            await self?.gapFillIfNeeded()
        }
    }

    @discardableResult
    private func applyCachedThreadIfAvailable() -> Bool {
        guard highlightMessageId == nil,
              let cached = messageCache?.entry(for: conversationId),
              !cached.messages.isEmpty else {
            return false
        }

        highestLoadedPage = cached.highestLoadedPage
        hasMoreMessages = cached.hasMoreMessages
        state = .loaded(MessageTimelineOrdering.sortedChronologically(cached.messages))
        recomputeMaxSequenceNo()
        restorePendingMessages()
        return true
    }

    // MARK: - Pending outbound

    private func restorePendingMessages() {
        let pending = pendingMessageStore.all(for: conversationId)
        guard !pending.isEmpty else { return }
        for item in pending {
            pendingBodiesByClientId[item.clientMessageId] = item.body
            pendingAttachmentsByClientId[item.clientMessageId] = item.imageAttachments
            pendingReplyByClientId[item.clientMessageId] = item.replyToMessageId
            let message = ChatMessage(
                id: item.clientMessageId,
                conversationId: item.conversationId,
                senderId: currentUserId,
                body: item.body,
                clientMessageId: item.clientMessageId,
                createdAt: item.createdAt,
                deliveryStatus: .failed,
                imageAttachments: item.imageAttachments
            )
            upsertIncomingMessage(message)
        }
    }

    private func retryFailedPendingSends() async {
        let failedIds = messages
            .filter { $0.senderId == currentUserId && $0.deliveryStatus == .failed }
            .map(\.id)
        for id in failedIds {
            await retrySend(messageId: id)
        }
    }

    private func rememberPending(
        clientMessageId: UUID,
        body: String,
        attachments: [MessageImageAttachment],
        replyToMessageId: UUID?
    ) {
        pendingBodiesByClientId[clientMessageId] = body
        pendingAttachmentsByClientId[clientMessageId] = attachments
        pendingReplyByClientId[clientMessageId] = replyToMessageId
    }

    private func persistFailedPending(clientMessageId: UUID) {
        let body = pendingBodiesByClientId[clientMessageId] ?? ""
        let attachments = pendingAttachmentsByClientId[clientMessageId] ?? []
        let replyTo = pendingReplyByClientId[clientMessageId] ?? nil
        let createdAt = messages.first(where: { $0.clientMessageId == clientMessageId })?.createdAt ?? .now
        pendingMessageStore.save(
            PendingOutboundMessage(
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                body: body,
                imageAttachments: attachments,
                replyToMessageId: replyTo,
                createdAt: createdAt,
                status: .failed
            )
        )
    }

    private func clearPending(clientMessageId: UUID) {
        pendingBodiesByClientId.removeValue(forKey: clientMessageId)
        pendingAttachmentsByClientId.removeValue(forKey: clientMessageId)
        pendingReplyByClientId.removeValue(forKey: clientMessageId)
        pendingMessageStore.remove(clientMessageId: clientMessageId)
    }

    // MARK: - Mark read (debounced)

    /// Marks up to `upToMessageId` as read.
    /// - Parameter requireNearBottom: when true, skip if the user is scrolled up reading history.
    ///   Opening the thread uses `false` so entering the chat counts as "đã xem".
    private func scheduleMarkRead(upToMessageId: UUID, requireNearBottom: Bool = true) {
        if requireNearBottom, !isNearBottom { return }
        if lastMarkedReadMessageId == upToMessageId { return }

        markReadTask?.cancel()
        markReadTask = Task { [weak self] in
            try? await Task.sleep(for: Self.markReadDebounce)
            guard !Task.isCancelled else { return }
            await self?.performMarkRead(
                upToMessageId: upToMessageId,
                requireNearBottom: requireNearBottom
            )
        }
    }

    private func performMarkRead(upToMessageId: UUID, requireNearBottom: Bool = true) async {
        if requireNearBottom, !isNearBottom { return }
        if lastMarkedReadMessageId == upToMessageId { return }
        // Only advance cursor — never mark an older message after a newer one.
        if let current = lastMarkedReadMessageId,
           let currentSeq = messages.first(where: { $0.id == current })?.sequenceNo,
           let nextSeq = messages.first(where: { $0.id == upToMessageId })?.sequenceNo,
           currentSeq > 0, nextSeq > 0, nextSeq < currentSeq {
            return
        }

        do {
            try await repository.markRead(conversationId: conversationId, upToMessageId: upToMessageId)
            lastMarkedReadMessageId = upToMessageId
            await onConversationRead?(conversationId)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "markRead"])
        }
    }

    // MARK: - Private helpers

    private func loadUntilMessage(id targetId: UUID) async throws {
        var messagesById: [UUID: ChatMessage] = [:]
        var page = 0
        var lastHasMore = false

        while page < Self.maxPagesForMessageLookup {
            let batch = try await fetchMessagesUseCase.execute(
                conversationId: conversationId,
                page: page,
                limit: Self.pageSize
            )
            if batch.items.isEmpty { break }
            lastHasMore = batch.hasMore
            for message in batch.items {
                messagesById[message.id] = message
            }
            if messagesById[targetId] != nil { break }
            page += 1
            if !batch.hasMore { break }
        }

        let sorted = messagesById.values.sorted { lhs, rhs in
            if lhs.sequenceNo > 0, rhs.sequenceNo > 0, lhs.sequenceNo != rhs.sequenceNo {
                return lhs.sequenceNo < rhs.sequenceNo
            }
            return lhs.createdAt < rhs.createdAt
        }
        highestLoadedPage = page
        hasMoreMessages = lastHasMore
        state = .loaded(sorted)
        recomputeMaxSequenceNo()
        restorePendingMessages()
        persistCache()

        if messagesById[targetId] != nil {
            activateHighlight(for: targetId)
            requestScrollToMessage(targetId)
        } else {
            requestScrollToBottom()
        }

        if let lastId = sorted.last?.id {
            scheduleMarkRead(upToMessageId: lastId, requireNearBottom: false)
            sendDeliveryAck(for: lastId)
        }
    }

    private func requestScrollToMessage(_ messageId: UUID) {
        scrollToMessageToken += 1
        _ = messageId
    }

    private func activateHighlight(for messageId: UUID) {
        highlightClearTask?.cancel()
        highlightedMessageId = messageId
        highlightClearTask = Task {
            try? await Task.sleep(for: Self.highlightDuration)
            guard !Task.isCancelled else { return }
            highlightedMessageId = nil
        }
    }

    private func updateMessage(at index: Int, with message: ChatMessage) {
        guard case .loaded(var messages) = state, messages.indices.contains(index) else { return }
        messages[index] = message
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(messages)
        }
        recomputeMaxSequenceNo()
        persistCache()
    }

    private func replaceMessage(matching clientMessageId: UUID, with message: ChatMessage) {
        guard case .loaded(var messages) = state else { return }
        if let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) {
            messages[index] = message
        } else {
            messages.append(message)
            messages = MessageTimelineOrdering.sortedChronologically(messages)
        }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(messages)
        }
        recomputeMaxSequenceNo()
        persistCache()
    }

    private func updateDeliveryStatus(for clientMessageId: UUID, status: MessageDeliveryStatus) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) else { return }
        messages[index] = messages[index].updating(deliveryStatus: status)
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(messages)
        }
        persistCache()
    }

    private func reconcileReaction(messageId: UUID, optimisticId: UUID, with server: Reaction) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let message = messages[index]
        var reactions = message.reactions.filter { $0.id != optimisticId }
        reactions.append(server)
        messages[index] = message.updating(reactions: reactions)
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(messages)
        }
        persistCache()
    }

    private func removeReaction(messageId: UUID, reactionId: UUID) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let message = messages[index]
        messages[index] = message.updating(
            reactions: message.reactions.filter { $0.id != reactionId }
        )
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(messages)
        }
        persistCache()
    }

    private func appendMessage(_ message: ChatMessage) {
        upsertIncomingMessage(message, animate: true, scrollToBottom: true)
    }

    func upsertIncomingMessage(
        _ message: ChatMessage,
        animate: Bool = false,
        scrollToBottom: Bool = false
    ) {
        guard isMessageVisible(message) else { return }
        guard case .loaded(var msgs) = state else { return }

        if let index = msgs.firstIndex(where: { $0.clientMessageId == message.clientMessageId || $0.id == message.id }) {
            // Prefer server payload (keeps clientMessageId match for optimistic → confirmed).
            msgs[index] = message
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                state = .loaded(msgs)
            }
        } else {
            msgs.append(message)
            msgs = MessageTimelineOrdering.sortedChronologically(msgs)
            if animate {
                withAnimation(ChatScrollAnimation.spring) {
                    state = .loaded(msgs)
                }
            } else {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    state = .loaded(msgs)
                }
            }
            if scrollToBottom {
                requestScrollToBottom()
            }
        }
        recomputeMaxSequenceNo()
        persistCache()
    }

    private func requestScrollToBottom() {
        scrollToBottomToken += 1
    }

    /// Scrolls to the latest message (send / open). Not used for composer focus.
    public func pinToLatest() {
        requestScrollToBottom()
    }

    private func registerFloatAnimation(for clientMessageId: UUID) {
        newlySentMessageIds.insert(clientMessageId)
        floatSwayByMessageId[clientMessageId] = CGFloat.random(in: -4...4)
        Task {
            try? await Task.sleep(for: .seconds(MessageSendAnimation.duration))
            newlySentMessageIds.remove(clientMessageId)
            floatSwayByMessageId.removeValue(forKey: clientMessageId)
        }
    }

    private func sendDeliveryAck(for messageId: UUID) {
        MessageDeliveryAckService.shared.acknowledge(
            conversationId: conversationId,
            messageId: messageId
        )
    }

    private func persistCache() {
        guard case .loaded(let messages) = state else { return }
        messageCache?.store(
            conversationId: conversationId,
            messages: messages,
            highestLoadedPage: highestLoadedPage,
            hasMoreMessages: hasMoreMessages
        )
    }

    private func recomputeMaxSequenceNo() {
        maxSequenceNo = messages.map(\.sequenceNo).max() ?? maxSequenceNo
    }

    private func bindWsEvents() {
        wsClient.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .connected:
                    self.scheduleGapFill()

                case .newMessage(let convId, let msg) where convId == self.conversationId:
                    self.upsertIncomingMessage(msg, scrollToBottom: self.isNearBottom)
                    self.scheduleMarkRead(upToMessageId: msg.id)
                    self.sendDeliveryAck(for: msg.id)
                    if msg.clientMessageId != msg.id {
                        self.clearPending(clientMessageId: msg.clientMessageId)
                    }

                case .readReceipt(let convId, let readerId, let upToMessageId, let upToSequence) where convId == self.conversationId:
                    self.applyReadReceipt(
                        readerId: readerId,
                        upToMessageId: upToMessageId,
                        upToSequence: upToSequence
                    )

                case .deliveryAck(let convId, let messageId) where convId == self.conversationId:
                    self.applyDeliveryAck(messageId: messageId)

                case .messageEdited(let convId, let messageId, _, let body) where convId == self.conversationId:
                    self.applyEditedMessage(messageId: messageId, body: body)

                case .messageRecalled(let convId, let messageId, _) where convId == self.conversationId:
                    self.applyRecalledMessage(messageId: messageId)

                case .typing(let convId, let userId, let isTyping) where convId == self.conversationId:
                    if self.isRemovedFromGroup { break }
                    self.applyRemoteTyping(userId: userId, isTyping: isTyping)

                case .groupMemberRemoved(let convId, let removedUserId, _)
                    where convId == self.conversationId && removedUserId == self.currentUserId:
                    self.markRemovedFromGroup()

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func markRemovedFromGroup() {
        leftAt = leftAt ?? Date()
        isGroupOwner = false
        stopLocalTyping()
        typingUserIds = []
        if case .loaded(let msgs) = state {
            state = .loaded(visibleMessages(msgs))
        }
    }

    private func isMessageVisible(_ message: ChatMessage) -> Bool {
        guard let leftAt else { return true }
        return message.createdAt <= leftAt
    }

    private func visibleMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.filter(isMessageVisible)
    }

    private func applyRemoteTyping(userId: UUID, isTyping: Bool) {
        guard userId != currentUserId else { return }
        remoteTypingTimeouts[userId]?.cancel()
        if isTyping {
            let wasTyping = typingUserIds.contains(userId)
            if !typingUserIds.contains(userId) {
                typingUserIds.append(userId)
            }
            if !wasTyping {
                requestScrollToBottom()
            }
            remoteTypingTimeouts[userId] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(MessagingTypingTiming.displayTimeout))
                guard !Task.isCancelled else { return }
                self?.removeRemoteTypingUser(userId)
            }
        } else {
            removeRemoteTypingUser(userId)
        }
    }

    private func removeRemoteTypingUser(_ userId: UUID) {
        remoteTypingTimeouts[userId]?.cancel()
        remoteTypingTimeouts[userId] = nil
        typingUserIds.removeAll { $0 == userId }
    }

    private func bindNetworkRetry() {
        guard let networkPathMonitor else { return }
        pathMonitorHandlerId = networkPathMonitor.onPathChange { [weak self] satisfied in
            guard satisfied else { return }
            Task { @MainActor [weak self] in
                await self?.retryFailedPendingSends()
            }
        }
    }

    private func bindForegroundGapFill() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleGapFill()
            }
        }
    }

    private func applyDeliveryAck(messageId: UUID) {
        guard case .loaded(let messages) = state,
              let next = MessageReadReceiptPresentation.applyingDeliveryAck(
                to: messages,
                currentUserId: currentUserId,
                messageId: messageId
              ) else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(next)
        }
        persistCache()
    }

    private func applyReadReceipt(readerId: UUID, upToMessageId: UUID, upToSequence: Int64?) {
        guard case .loaded(let messages) = state,
              let next = MessageReadReceiptPresentation.applyingReadReceipt(
                to: messages,
                currentUserId: currentUserId,
                readerId: readerId,
                upToMessageId: upToMessageId,
                upToSequence: upToSequence
              ) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            state = .loaded(next)
        }
        persistCache()
    }

    private func applyEditedMessage(messageId: UUID, body: String) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index] = messages[index].updating(body: body)
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(messages)
        }
        persistCache()
    }

    private func applyRecalledMessage(messageId: UUID) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index] = messages[index].updating(body: "")
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            state = .loaded(messages)
        }
        persistCache()
    }

    private func resolveImageAttachments(
        from submissions: [CommentSubmissionAttachment]
    ) async throws -> [MessageImageAttachment] {
        var attachments: [MessageImageAttachment] = []
        attachments.reserveCapacity(submissions.count)

        for submission in submissions {
            switch submission.kind {
            case .image:
                if let attachment = MessageAttachmentMapper.messageImage(from: submission) {
                    attachments.append(attachment)
                } else if let data = submission.data {
                    attachments.append(try await uploadImage(data, submission.mimeType ?? "image/jpeg"))
                }
            case .gif:
                if let attachment = MessageAttachmentMapper.messageGif(from: submission) {
                    attachments.append(attachment)
                }
            default:
                break
            }
        }

        return attachments
    }

    private func replySnippet(from message: ChatMessage) -> String {
        let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(200))
        }
        return ""
    }
}
