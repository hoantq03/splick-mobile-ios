import Combine
import Foundation
import SplickDomain
import Common
import Networking

public enum MessagingWsEvent: Sendable {
    case connected
    case newMessage(conversationId: UUID, message: ChatMessage)
    case readReceipt(conversationId: UUID, readerId: UUID, upToMessageId: UUID, upToSequence: Int64?)
    case deliveryAck(conversationId: UUID, messageId: UUID)
    case typing(conversationId: UUID, userId: UUID, isTyping: Bool)
    case messageEdited(conversationId: UUID, messageId: UUID, senderId: UUID, body: String)
    case messageRecalled(conversationId: UUID, messageId: UUID, senderId: UUID)
    case presence(userId: UUID, isOnline: Bool, lastSeenAt: Date?)
    case groupMemberRemoved(conversationId: UUID, removedUserId: UUID, selfLeave: Bool)
}

@MainActor
public final class MessagingWebSocketClient: ObservableObject {

    private var webSocketTask: URLSessionWebSocketTask?
    private var connectionLoopTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var isConnected = false
    private var shouldRun = false
    private let minReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 60.0
    private let encoder = JSONEncoder()

    private let ticketProvider: @Sendable () async throws -> String
    private let deviceIdProvider: @Sendable () -> String
    private let forceTokenRefresh: @Sendable () async -> Void

    public let eventSubject = PassthroughSubject<MessagingWsEvent, Never>()

    public init(
        ticketProvider: @escaping @Sendable () async throws -> String,
        deviceIdProvider: @escaping @Sendable () -> String,
        forceTokenRefresh: @escaping @Sendable () async -> Void = {}
    ) {
        self.ticketProvider = ticketProvider
        self.deviceIdProvider = deviceIdProvider
        self.forceTokenRefresh = forceTokenRefresh
    }

    public func connect() {
        guard !shouldRun else { return }
        shouldRun = true
        connectionLoopTask?.cancel()
        connectionLoopTask = Task { [weak self] in
            await self?.runConnectionLoop()
        }
    }

    public func disconnect() {
        shouldRun = false
        isConnected = false
        connectionLoopTask?.cancel()
        connectionLoopTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    public func sendDeliveryAck(conversationId: UUID, messageId: UUID) {
        sendJSON([
            "type": "message.delivered",
            "conversationId": conversationId.uuidString,
            "messageId": messageId.uuidString,
        ])
    }

    public func sendTyping(conversationId: UUID, isTyping: Bool) {
        sendJSON([
            "type": isTyping ? "typing.start" : "typing.stop",
            "conversationId": conversationId.uuidString,
        ])
    }

    // MARK: - Connection loop (single Task, exponential backoff + jitter)

    private func runConnectionLoop() async {
        var reconnectDelay = minReconnectDelay
        var handshakeFailures = 0

        while shouldRun, !Task.isCancelled {
            do {
                let ticket = try await ticketProvider()
                let deviceId = deviceIdProvider()
                let baseURL = AppConstants.API.wsBaseURL
                let encodedTicket = ticket.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ticket
                let encodedDevice = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId
                guard let url = URL(string: "\(baseURL)/v1/messaging/ws?ticket=\(encodedTicket)&deviceId=\(encodedDevice)") else {
                    Log.error("Invalid WS URL", category: .network)
                    break
                }

                let task = URLSession.shared.webSocketTask(with: url)
                webSocketTask = task
                task.resume()

                guard await sendPing(on: task) else {
                    handshakeFailures += 1
                    Log.warning(
                        "WS handshake failed (\(handshakeFailures)) — messaging service may be down",
                        category: .network
                    )
                    task.cancel(with: .goingAway, reason: nil)
                    webSocketTask = nil

                    if handshakeFailures >= 3 {
                        handshakeFailures = 0
                        await forceTokenRefresh()
                    }

                    let delay = jitteredDelay(reconnectDelay)
                    reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }

                handshakeFailures = 0
                reconnectDelay = minReconnectDelay
                isConnected = true
                eventSubject.send(.connected)
                startPing()
                await receiveLoop()
                isConnected = false
                pingTask?.cancel()
                pingTask = nil
                webSocketTask = nil

                guard shouldRun, !Task.isCancelled else { break }
                let delay = jitteredDelay(reconnectDelay)
                reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
                Log.info("WS reconnecting in \(String(format: "%.1f", delay))s", category: .network)
                try? await Task.sleep(for: .seconds(delay))
            } catch {
                guard shouldRun, !Task.isCancelled else { break }
                Log.warning("WS ticket/connect error: \(error.localizedDescription)", category: .network)
                handshakeFailures += 1
                if handshakeFailures >= 3 {
                    handshakeFailures = 0
                    await forceTokenRefresh()
                }
                let delay = jitteredDelay(reconnectDelay)
                reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
                try? await Task.sleep(for: .seconds(delay))
            }
        }

        isConnected = false
    }

    private func jitteredDelay(_ base: TimeInterval) -> TimeInterval {
        let jitterFactor = Double.random(in: 0.7...1.3) // ±30%
        return max(minReconnectDelay, base * jitterFactor)
    }

    private func sendPing(on task: URLSessionWebSocketTask) async -> Bool {
        await withCheckedContinuation { continuation in
            let gate = ContinuationGate(continuation)
            task.sendPing { error in
                gate.resume(returning: error == nil)
            }
        }
    }

    private func receiveLoop() async {
        while isConnected, shouldRun, let task = webSocketTask, !Task.isCancelled {
            do {
                let message = try await task.receive()
                handleMessage(message)
            } catch {
                guard isConnected, shouldRun else { return }
                Log.warning("WS receive error — will reconnect: \(error.localizedDescription)", category: .network)
                return
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else { return }
        Task { [weak self] in
            let event = await Task.detached(priority: .utility) {
                guard let data = text.data(using: .utf8) else { return nil as MessagingWsEvent? }
                return MessagingWsEventDecoder.decode(data)
            }.value
            guard let event else { return }
            self?.eventSubject.send(event)
        }
    }

    private func startPing() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while let self = self, self.isConnected, self.shouldRun {
                try? await Task.sleep(for: .seconds(30))
                self.webSocketTask?.sendPing { _ in }
            }
        }
    }

    private func sendJSON(_ payload: [String: String]) {
        guard isConnected, let task = webSocketTask else { return }
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { error in
            if let error {
                Log.warning("WS send failed: \(error.localizedDescription)", category: .network)
            }
        }
    }
}

private final class ContinuationGate<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: value)
    }
}
