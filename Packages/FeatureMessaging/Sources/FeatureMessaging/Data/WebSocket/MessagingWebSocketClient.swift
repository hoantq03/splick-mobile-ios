import Combine
import Foundation
import SplickDomain
import Common
import Networking

// MARK: - Event stream

public enum MessagingWsEvent: Sendable {
    case connected
    case newMessage(conversationId: UUID, message: ChatMessage)
    case readReceipt(conversationId: UUID, readerId: UUID, upToMessageId: UUID, upToSequence: Int64?)
    case deliveryAck(conversationId: UUID, messageId: UUID)
    case typing(conversationId: UUID, userId: UUID, isTyping: Bool)
    case messageEdited(conversationId: UUID, messageId: UUID, senderId: UUID, body: String, editedAt: Date?)
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
    /// Bumped on every `connect()` / `disconnect()` so stale connection loops exit promptly.
    private var connectGeneration = 0
    private let minReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 60.0
    private let encoder = JSONEncoder()

    private let ticketProvider: @Sendable () async throws -> String
    private let deviceIdProvider: @Sendable () -> String
    private let forceTokenRefresh: @Sendable () async -> Void

    internal let eventSubject = PassthroughSubject<MessagingWsEvent, Never>()
    private var eventBuffer: [MessagingWsEvent] = []
    private let maxEventBuffer = 64

    /// Replays recent events to new subscribers (late-bound view models after connect).
    public func eventsPublisher() -> AnyPublisher<MessagingWsEvent, Never> {
        let buffered = eventBuffer
        guard !buffered.isEmpty else {
            return eventSubject.eraseToAnyPublisher()
        }
        return buffered.publisher
            .merge(with: eventSubject)
            .eraseToAnyPublisher()
    }

    public init(
        ticketProvider: @escaping @Sendable () async throws -> String,
        deviceIdProvider: @escaping @Sendable () -> String,
        forceTokenRefresh: @escaping @Sendable () async -> Void = {}
    ) {
        self.ticketProvider = ticketProvider
        self.deviceIdProvider = deviceIdProvider
        self.forceTokenRefresh = forceTokenRefresh
    }

    /// Ensures a live socket while the app is foregrounded. Safe to call repeatedly.
    public func connect() {
        shouldRun = true
        if isConnected, connectionLoopTask != nil, connectionLoopTask?.isCancelled == false {
            return
        }
        startConnectionLoop()
    }

    /// Tears down any stale socket and starts a fresh connection (use after background resume).
    public func reconnect() {
        shouldRun = true
        isConnected = false
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        startConnectionLoop()
    }

    private func startConnectionLoop() {
        connectGeneration += 1
        let generation = connectGeneration
        connectionLoopTask?.cancel()
        connectionLoopTask = Task { [weak self] in
            guard let self, generation == self.connectGeneration else { return }
            await self.runConnectionLoop(generation: generation)
        }
    }

    private func publish(_ event: MessagingWsEvent) {
        eventBuffer.append(event)
        if eventBuffer.count > maxEventBuffer {
            eventBuffer.removeFirst(eventBuffer.count - maxEventBuffer)
        }
        eventSubject.send(event)
    }

    public func disconnect() {
        shouldRun = false
        isConnected = false
        connectGeneration += 1
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

    private func runConnectionLoop(generation: Int) async {
        var reconnectDelay = minReconnectDelay
        var ticketFailures = 0

        while shouldRun,
              generation == connectGeneration,
              !Task.isCancelled {
            do {
                let ticket = try await ticketProvider()
                let deviceId = deviceIdProvider()
                let baseURL = AppConstants.API.wsBaseURL
                let encodedTicket = ticket.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ticket
                let encodedDevice = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId
                guard let url = URL(string: "\(baseURL)/v1/messaging/ws?ticket=\(encodedTicket)&deviceId=\(encodedDevice)") else {
                    Log.error("Invalid WS URL", category: .network)
                    let delay = jitteredDelay(reconnectDelay)
                    reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }

                let task = URLSession.shared.webSocketTask(with: url)
                webSocketTask = task
                task.resume()

                ticketFailures = 0
                reconnectDelay = minReconnectDelay
                isConnected = true
                Log.info("Messaging WS connected", category: .network)
                publish(.connected)
                startPing()
                await receiveLoop(generation: generation)
                isConnected = false
                pingTask?.cancel()
                pingTask = nil
                webSocketTask = nil

                guard shouldRun, generation == connectGeneration, !Task.isCancelled else { break }
                let delay = jitteredDelay(reconnectDelay)
                reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
                Log.info("WS reconnecting in \(String(format: "%.1f", delay))s", category: .network)
                try? await Task.sleep(for: .seconds(delay))
            } catch {
                guard shouldRun, generation == connectGeneration, !Task.isCancelled else { break }
                Log.warning("WS ticket/connect error: \(error.localizedDescription)", category: .network)
                ticketFailures += 1
                if ticketFailures >= 3 {
                    ticketFailures = 0
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

    private func receiveLoop(generation: Int) async {
        while isConnected,
              shouldRun,
              generation == connectGeneration,
              let task = webSocketTask,
              !Task.isCancelled {
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
        Task { @MainActor [weak self] in
            let event = await Task.detached(priority: .utility) {
                guard let data = text.data(using: .utf8) else { return nil as MessagingWsEvent? }
                return MessagingWsEventDecoder.decode(data)
            }.value
            guard let event else {
                Log.warning("WS event decode failed", category: .network, metadata: ["preview": String(text.prefix(160))])
                return
            }
            self?.publish(event)
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
