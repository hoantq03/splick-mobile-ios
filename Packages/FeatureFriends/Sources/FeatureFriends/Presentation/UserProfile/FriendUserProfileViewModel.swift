import Foundation
import SplickDomain

public enum FriendProfileMode: Sendable {
    case friend
    case stranger
    case blocked
}

@MainActor
public final class FriendUserProfileViewModel: ObservableObject {
    @Published var user: UserSummary
    @Published var nicknameDraft = ""
    @Published var isProcessing = false
    @Published var alertMessage: String?
    @Published var showNicknameEditor = false
    @Published var showRemoveConfirm = false
    @Published var showBlockConfirm = false

    public let mode: FriendProfileMode

    private let removeFriendUseCase: RemoveFriendUseCaseProtocol?
    private let setNicknameUseCase: SetFriendNicknameUseCaseProtocol?
    private let blockUserUseCase: BlockUserUseCaseProtocol?
    private let unblockUserUseCase: UnblockUserUseCaseProtocol?
    private let onRelationshipChanged: () -> Void

    public init(
        user: UserSummary,
        mode: FriendProfileMode,
        removeFriendUseCase: RemoveFriendUseCaseProtocol?,
        setNicknameUseCase: SetFriendNicknameUseCaseProtocol?,
        blockUserUseCase: BlockUserUseCaseProtocol?,
        unblockUserUseCase: UnblockUserUseCaseProtocol?,
        onRelationshipChanged: @escaping () -> Void
    ) {
        self.user = user
        self.mode = mode
        self.removeFriendUseCase = removeFriendUseCase
        self.setNicknameUseCase = setNicknameUseCase
        self.blockUserUseCase = blockUserUseCase
        self.unblockUserUseCase = unblockUserUseCase
        self.onRelationshipChanged = onRelationshipChanged
        self.nicknameDraft = user.displayName
    }

    func removeFriend() async {
        guard let removeFriendUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await removeFriendUseCase.execute(friendUserId: user.id)
            onRelationshipChanged()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func saveNickname() async {
        guard let setNicknameUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = trimmed.isEmpty ? nil : trimmed
        do {
            user = try await setNicknameUseCase.execute(friendUserId: user.id, nickname: nickname)
            nicknameDraft = user.displayName
            showNicknameEditor = false
            onRelationshipChanged()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func blockUser() async {
        guard let blockUserUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await blockUserUseCase.execute(userId: user.id)
            onRelationshipChanged()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func unblockUser() async {
        guard let unblockUserUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await unblockUserUseCase.execute(userId: user.id)
            onRelationshipChanged()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
