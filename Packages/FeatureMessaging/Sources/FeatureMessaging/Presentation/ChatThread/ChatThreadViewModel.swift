import Foundation
import Combine
import Common
import SplickDomain
import SwiftUI

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
    @Published public private(set) var scrollToBottomToken = 0
    @Published public private(set) var scrollToMessageToken = 0
    @Published public private(set) var highlightedMessageId: UUID?
    @Published public private(set) var newlySentMessageIds: Set<UUID> = []

    private static let maxPagesForMessageLookup = 10
    private static let pageSize = 30
    private static let highlightDuration: Duration = .seconds(2)

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
    private let wsClient: MessagingWebSocketClient
    private var cancellables = Set<AnyCancellable>()
    private var highlightClearTask: Task<Void, Never>?
    private var floatSwayByMessageId: [UUID: CGFloat] = [:]
    private var pendingBodiesByClientId: [UUID: String] = [:]

    public init(
        conversationId: UUID,
        currentUserId: UUID,
        highlightMessageId: UUID? = nil,
        fetchMessagesUseCase: FetchMessagesUseCase,
        sendMessageUseCase: SendMessageUseCase,
        reactToMessageUseCase: ReactToMessageUseCaseProtocol,
        repository: MessagingRepositoryProtocol,
        wsClient: MessagingWebSocketClient
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.highlightMessageId = highlightMessageId
        self.fetchMessagesUseCase = fetchMessagesUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.reactToMessageUseCase = reactToMessageUseCase
        self.repository = repository
        self.wsClient = wsClient
        bindWsEvents()
    }

    public var messages: [ChatMessage] {
        if case .loaded(let msgs) = state { return msgs }
        return []
    }

    public func floatSway(for messageId: UUID) -> CGFloat {
        floatSwayByMessageId[messageId] ?? 0
    }

    public func loadIfNeeded() async {
        switch state {
        case .loaded, .loading:
            return
        case .idle, .failed:
            await load()
        }
    }

    public func load() async {
        guard !isLoading else { return }
        state = .loading
        do {
            if let targetId = highlightMessageId {
                try await loadUntilMessage(id: targetId)
            } else {
                let msgs = try await fetchMessagesUseCase.execute(conversationId: conversationId)
                let sorted = msgs.reversed() as [ChatMessage]
                state = .loaded(sorted)
                requestScrollToBottom()
                if let lastId = sorted.last?.id {
                    markRead(upToMessageId: lastId)
                    sendDeliveryAck(for: lastId)
                }
            }
        } catch {
            Log.error(error, category: .network, metadata: ["action": "loadMessages"])
            state = .failed(error.localizedDescription)
        }
    }

    public func send(body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let clientMessageId = UUID()
        let optimistic = ChatMessage(
            id: clientMessageId,
            conversationId: conversationId,
            senderId: currentUserId,
            body: trimmed,
            clientMessageId: clientMessageId,
            createdAt: Date(),
            deliveryStatus: .sending
        )

        pendingBodiesByClientId[clientMessageId] = trimmed
        registerFloatAnimation(for: clientMessageId)
        appendMessage(optimistic)
        isSending = true

        do {
            let sent = try await sendMessageUseCase.execute(
                conversationId: conversationId,
                body: trimmed,
                clientMessageId: clientMessageId
            )
            replaceMessage(
                matching: clientMessageId,
                with: sent.updating(deliveryStatus: .sent)
            )
            pendingBodiesByClientId.removeValue(forKey: clientMessageId)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "sendMessage"])
            updateDeliveryStatus(for: clientMessageId, status: .failed)
        }

        isSending = false
    }

    public func retrySend(messageId: UUID) async {
        guard case .loaded(let messages) = state,
              let message = messages.first(where: { $0.id == messageId }),
              message.deliveryStatus == .failed else { return }

        let body = pendingBodiesByClientId[message.clientMessageId] ?? message.body
        updateDeliveryStatus(for: message.clientMessageId, status: .sending)

        do {
            let sent = try await sendMessageUseCase.execute(
                conversationId: conversationId,
                body: body,
                clientMessageId: message.clientMessageId
            )
            replaceMessage(
                matching: message.clientMessageId,
                with: sent.updating(deliveryStatus: .sent)
            )
            pendingBodiesByClientId.removeValue(forKey: message.clientMessageId)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "retrySendMessage"])
            updateDeliveryStatus(for: message.clientMessageId, status: .failed)
        }
    }

    public func markRead(upToMessageId: UUID) {
        Task {
            try? await repository.markRead(conversationId: conversationId, upToMessageId: upToMessageId)
        }
    }

    @discardableResult
    public func react(to messageId: UUID, emoji: String) -> String? {
        guard case .loaded(let messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return nil
        }

        let message = messages[index]
        let distinctEmojis = Set(message.reactions.filter { $0.userId == currentUserId }.map(\.emoji))
        if !distinctEmojis.contains(emoji),
           distinctEmojis.count >= ReactionConstants.maxDistinctEmojiPerUser {
            return "Mỗi tin nhắn bạn chỉ được dùng tối đa 5 loại emoji."
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

    private func loadUntilMessage(id targetId: UUID) async throws {
        var messagesById: [UUID: ChatMessage] = [:]
        var page = 0

        while page < Self.maxPagesForMessageLookup {
            let batch = try await fetchMessagesUseCase.execute(
                conversationId: conversationId,
                page: page,
                limit: Self.pageSize
            )
            if batch.isEmpty { break }
            for message in batch {
                messagesById[message.id] = message
            }
            if messagesById[targetId] != nil { break }
            page += 1
        }

        let sorted = messagesById.values.sorted { $0.createdAt < $1.createdAt }
        state = .loaded(sorted)

        if messagesById[targetId] != nil {
            activateHighlight(for: targetId)
            requestScrollToMessage(targetId)
        } else {
            requestScrollToBottom()
        }

        if let lastId = sorted.last?.id {
            markRead(upToMessageId: lastId)
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
        state = .loaded(messages)
    }

    private func replaceMessage(matching clientMessageId: UUID, with message: ChatMessage) {
        guard case .loaded(var messages) = state else { return }
        if let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) {
            newlySentMessageIds.remove(messages[index].id)
            messages[index] = message
        } else {
            messages.append(message)
        }
        withAnimation(ChatScrollAnimation.spring) {
            state = .loaded(messages)
        }
        requestScrollToBottom()
    }

    private func updateDeliveryStatus(for clientMessageId: UUID, status: MessageDeliveryStatus) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) else { return }
        messages[index] = messages[index].updating(deliveryStatus: status)
        state = .loaded(messages)
    }

    private func reconcileReaction(messageId: UUID, optimisticId: UUID, with server: Reaction) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let message = messages[index]
        var reactions = message.reactions.filter { $0.id != optimisticId }
        reactions.append(server)
        messages[index] = message.updating(reactions: reactions)
        state = .loaded(messages)
    }

    private func removeReaction(messageId: UUID, reactionId: UUID) {
        guard case .loaded(var messages) = state,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let message = messages[index]
        messages[index] = message.updating(
            reactions: message.reactions.filter { $0.id != reactionId }
        )
        state = .loaded(messages)
    }

    private func appendMessage(_ message: ChatMessage) {
        guard case .loaded(var msgs) = state else { return }
        guard !msgs.contains(where: { $0.id == message.id || $0.clientMessageId == message.clientMessageId }) else { return }
        msgs.append(message)
        withAnimation(ChatScrollAnimation.spring) {
            state = .loaded(msgs)
        }
        requestScrollToBottom()
    }

    private func requestScrollToBottom() {
        scrollToBottomToken += 1
    }

    private func registerFloatAnimation(for messageId: UUID) {
        newlySentMessageIds.insert(messageId)
        floatSwayByMessageId[messageId] = CGFloat.random(in: -4...4)
        Task {
            try? await Task.sleep(for: .seconds(MessageSendAnimation.duration))
            newlySentMessageIds.remove(messageId)
            floatSwayByMessageId.removeValue(forKey: messageId)
        }
    }

    private func sendDeliveryAck(for messageId: UUID) {
        wsClient.sendDeliveryAck(conversationId: conversationId, messageId: messageId)
    }

    private func bindWsEvents() {
        wsClient.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .newMessage(let convId, let msg) where convId == self.conversationId:
                    self.appendMessage(msg)
                    self.markRead(upToMessageId: msg.id)
                    self.sendDeliveryAck(for: msg.id)

                case .readReceipt(let convId, _, let upToMessageId) where convId == self.conversationId:
                    self.applyReadReceipt(upToMessageId: upToMessageId)

                case .deliveryAck(let convId, let messageId) where convId == self.conversationId:
                    self.applyDeliveryAck(messageId: messageId)

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func applyDeliveryAck(messageId: UUID) {
        guard case .loaded(var messages) = state else { return }
        var changed = false
        for index in messages.indices {
            let message = messages[index]
            guard message.senderId == currentUserId,
                  message.id == messageId,
                  message.deliveryStatus == .sent || message.deliveryStatus == .sending else { continue }
            messages[index] = message.updating(deliveryStatus: .delivered)
            changed = true
        }
        if changed { state = .loaded(messages) }
    }

    private func applyReadReceipt(upToMessageId: UUID) {
        guard case .loaded(var messages) = state,
              let upToIndex = messages.firstIndex(where: { $0.id == upToMessageId }) else { return }

        var changed = false
        for index in 0...upToIndex {
            let message = messages[index]
            guard message.senderId == currentUserId,
                  message.deliveryStatus != .read,
                  message.deliveryStatus != .failed else { continue }
            messages[index] = message.updating(deliveryStatus: .read)
            changed = true
        }
        if changed { state = .loaded(messages) }
    }
}
