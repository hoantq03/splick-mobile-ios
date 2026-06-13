import Combine
import Foundation
import SplickDomain
import Common

public enum MessagingWsEvent: Sendable {
    case newMessage(conversationId: UUID, message: ChatMessage)
    case readReceipt(conversationId: UUID, readerId: UUID, upToMessageId: UUID)
}

@MainActor
public final class MessagingWebSocketClient: ObservableObject {

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var isConnected = false
    private var reconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 60.0
    private let decoder = JSONDecoder.apiDecoder

    // Token provider — refreshed before each connection attempt.
    private let tokenProvider: @Sendable () async -> String?

    /// Multicast subject — all subscribers (ConversationListVM, ChatThreadVM, etc.) receive every event.
    public let eventSubject = PassthroughSubject<MessagingWsEvent, Never>()

    public init(tokenProvider: @escaping @Sendable () async -> String?) {
        self.tokenProvider = tokenProvider
    }

    public func connect() {
        guard !isConnected else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            await self?.attemptConnect()
        }
    }

    public func disconnect() {
        isConnected = false
        reconnectTask?.cancel()
        pingTask?.cancel()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        reconnectDelay = 1.0
    }

    private func attemptConnect() async {
        guard let token = await tokenProvider() else {
            Log.warning("WS connect skipped: no token", category: .network)
            return
        }
        let baseURL = AppConstants.API.wsBaseURL
        guard let url = URL(string: "\(baseURL)/v1/messaging/ws?token=\(token)") else {
            Log.error("Invalid WS URL", category: .network)
            return
        }
        let session = URLSession.shared
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        reconnectDelay = 1.0
        startPing()
        await receiveLoop()
    }

    private func receiveLoop() async {
        while isConnected, let task = webSocketTask {
            do {
                let message = try await task.receive()
                handleMessage(message)
            } catch {
                guard isConnected else { return }
                Log.warning("WS receive error — will reconnect: \(error.localizedDescription)", category: .network)
                isConnected = false
                pingTask?.cancel()
                await scheduleReconnect()
                return
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }

        guard let envelope = try? JSONDecoder().decode(WsEventEnvelope.self, from: data) else { return }

        switch envelope.type {
        case "message.new":
            if let event = try? decoder.decode(WsNewMessageEvent.self, from: data) {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = iso.date(from: event.message.createdAt) ?? Date()
                let msg = ChatMessage(
                    id: event.message.id,
                    conversationId: event.conversationId,
                    senderId: event.message.senderId,
                    body: event.message.body,
                    clientMessageId: UUID(),
                    createdAt: date
                )
                eventSubject.send(.newMessage(conversationId: event.conversationId, message: msg))
            }
        case "message.read":
            if let event = try? decoder.decode(WsReadReceiptEvent.self, from: data) {
                eventSubject.send(.readReceipt(
                    conversationId: event.conversationId,
                    readerId: event.readerId,
                    upToMessageId: event.upToMessageId
                ))
            }
        default:
            break
        }
    }

    private func startPing() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while let self = self, self.isConnected {
                try? await Task.sleep(for: .seconds(30))
                self.webSocketTask?.sendPing { _ in }
            }
        }
    }

    private func scheduleReconnect() async {
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
        Log.info("WS reconnecting in \(delay)s", category: .network)
        try? await Task.sleep(for: .seconds(delay))
        guard isConnected == false else { return }
        await attemptConnect()
    }

    private struct WsEventEnvelope: Decodable {
        let type: String
    }
}
