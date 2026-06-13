import Foundation
import Combine
import Common
import SplickDomain

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

    public let conversationId: UUID
    private let fetchMessagesUseCase: FetchMessagesUseCase
    private let sendMessageUseCase: SendMessageUseCase
    private let repository: MessagingRepositoryProtocol
    private let wsClient: MessagingWebSocketClient
    private var cancellables = Set<AnyCancellable>()

    public init(
        conversationId: UUID,
        fetchMessagesUseCase: FetchMessagesUseCase,
        sendMessageUseCase: SendMessageUseCase,
        repository: MessagingRepositoryProtocol,
        wsClient: MessagingWebSocketClient
    ) {
        self.conversationId = conversationId
        self.fetchMessagesUseCase = fetchMessagesUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.repository = repository
        self.wsClient = wsClient
        bindWsEvents()
    }

    public var messages: [ChatMessage] {
        if case .loaded(let msgs) = state { return msgs }
        return []
    }

    public func load() async {
        state = .loading
        do {
            let msgs = try await fetchMessagesUseCase.execute(conversationId: conversationId)
            let sorted = msgs.reversed() as [ChatMessage]
            state = .loaded(sorted)
            // Mark thread read after initial load if there are messages.
            if let lastId = sorted.last?.id {
                markRead(upToMessageId: lastId)
            }
        } catch {
            Log.error(error, category: .network, metadata: ["action": "loadMessages"])
            state = .failed(error.localizedDescription)
        }
    }

    public func send(body: String) async {
        guard !body.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true
        do {
            let sent = try await sendMessageUseCase.execute(conversationId: conversationId, body: body)
            appendMessage(sent)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "sendMessage"])
        }
        isSending = false
    }

    public func markRead(upToMessageId: UUID) {
        Task {
            try? await repository.markRead(conversationId: conversationId, upToMessageId: upToMessageId)
        }
    }

    private func appendMessage(_ message: ChatMessage) {
        guard case .loaded(var msgs) = state else { return }
        // Deduplicate: skip if message with same id already present.
        guard !msgs.contains(where: { $0.id == message.id }) else { return }
        msgs.append(message)
        state = .loaded(msgs)
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
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
