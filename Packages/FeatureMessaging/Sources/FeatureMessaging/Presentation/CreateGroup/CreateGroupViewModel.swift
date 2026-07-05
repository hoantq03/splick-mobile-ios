import Foundation
import SplickDomain

@MainActor
public final class CreateGroupConversationViewModel: ObservableObject {
    @Published public var groupName = ""
    @Published public var selectedFriendIds: Set<UUID> = []
    @Published public private(set) var isSubmitting = false
    @Published public var errorMessage: String?

    private let createGroupUseCase: CreateGroupConversationUseCase

    public init(createGroupUseCase: CreateGroupConversationUseCase) {
        self.createGroupUseCase = createGroupUseCase
    }

    public var canSubmit: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedFriendIds.count >= 1
            && !isSubmitting
    }

    public func toggleFriend(_ friendId: UUID) {
        if selectedFriendIds.contains(friendId) {
            selectedFriendIds.remove(friendId)
        } else {
            selectedFriendIds.insert(friendId)
        }
    }

    public func createGroup() async -> Conversation? {
        guard canSubmit else { return nil }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            return try await createGroupUseCase.execute(
                name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarUrl: nil,
                memberUserIds: Array(selectedFriendIds)
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
