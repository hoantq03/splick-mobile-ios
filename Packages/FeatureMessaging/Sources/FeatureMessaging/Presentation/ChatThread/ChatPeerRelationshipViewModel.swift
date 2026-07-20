import Foundation

@MainActor
public final class ChatPeerRelationshipViewModel: ObservableObject {
    @Published public private(set) var status: ChatPeerRelationState = .unknown
    @Published public var isProcessing = false
    @Published public var showBlockConfirm = false
    @Published public var showRemoveConfirm = false

    public let isActive: Bool
    private let peerUserId: UUID
    private let actions: ChatPeerRelationshipActions

    public init(peerUserId: UUID, actions: ChatPeerRelationshipActions, isActive: Bool = true) {
        self.peerUserId = peerUserId
        self.actions = actions
        self.isActive = isActive
    }

    public static func inert() -> ChatPeerRelationshipViewModel {
        ChatPeerRelationshipViewModel(
            peerUserId: UUID(),
            actions: .disabled,
            isActive: false
        )
    }

    public var showsAddFriendBanner: Bool {
        isActive && status.showsAddFriendBanner
    }

    public var isBlocked: Bool {
        isActive && status.isBlocked
    }

    public var canRemoveFriend: Bool {
        isActive && status.canRemoveFriend
    }

    public func loadIfNeeded() async {
        guard isActive, status == .unknown else { return }
        await refresh()
    }

    public func refresh() async {
        guard isActive else { return }
        status = await actions.fetchStatus(peerUserId)
    }

    public func blockUser() async {
        guard isActive else { return }
        isProcessing = true
        status = .blocked
        defer { isProcessing = false }
        do {
            try await actions.blockUser(peerUserId)
        } catch {
            await refresh()
        }
    }

    public func unblockUser() async {
        guard isActive else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await actions.unblockUser(peerUserId)
            await refresh()
        } catch {
            await refresh()
        }
    }

    public func removeFriend() async {
        guard isActive else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await actions.removeFriend(peerUserId)
            status = .stranger
        } catch {
            await refresh()
        }
    }

    public func addFriend() async {
        guard isActive else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await actions.addFriend(peerUserId)
            status = .requestSent
        } catch {
            await refresh()
        }
    }

    public func acceptFriendRequest() async {
        guard isActive else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await actions.acceptFriendRequest(peerUserId)
            status = .friends
        } catch {
            await refresh()
        }
    }

    public func cancelFriendRequest() async {
        guard isActive else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await actions.cancelFriendRequest(peerUserId)
            status = .stranger
        } catch {
            await refresh()
        }
    }
}
