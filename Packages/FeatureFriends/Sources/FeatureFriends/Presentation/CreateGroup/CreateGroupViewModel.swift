import Foundation
import Combine
import SwiftUI
import PhotosUI
import UIKit
import FeatureMedia
import Localization
import SplickDomain

@MainActor
public final class CreateGroupViewModel: ObservableObject {
    @Published var name = ""
    @Published var groupDescription = ""
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var previewImage: UIImage?
    @Published var selectedMemberIds: Set<UUID> = []
    @Published var memberSearchQuery = ""
    @Published var isMemberSearchFocused = false
    @Published private(set) var friends: [UserSummary]
    @Published private(set) var isLoadingFriends = false
    @Published private(set) var friendsLoadErrorMessage: String?
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let createGroupUseCase: CreateGroupUseCaseProtocol
    private let inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol
    private let uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol
    private let updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol
    private let openLinkedGroupConversation: (_ groupId: UUID, _ name: String, _ memberUserIds: [UUID]) async throws -> Void
    private let languageService: LanguageService
    private let onSuccess: (SplickDomain.Group, [UUID]) -> Void

    public init(
        friends: [UserSummary],
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        createGroupUseCase: CreateGroupUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol,
        updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol,
        openLinkedGroupConversation: @escaping (_ groupId: UUID, _ name: String, _ memberUserIds: [UUID]) async throws -> Void = { _, _, _ in },
        languageService: LanguageService,
        onSuccess: @escaping (SplickDomain.Group, [UUID]) -> Void
    ) {
        self.friends = friends
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.createGroupUseCase = createGroupUseCase
        self.inviteFriendsUseCase = inviteFriendsUseCase
        self.uploadGroupAvatarUseCase = uploadGroupAvatarUseCase
        self.updateGroupAvatarUseCase = updateGroupAvatarUseCase
        self.openLinkedGroupConversation = openLinkedGroupConversation
        self.languageService = languageService
        self.onSuccess = onSuccess
    }

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var selectedMembers: [UserSummary] {
        friends.filter { selectedMemberIds.contains($0.id) }
    }

    var shouldShowMemberSuggestions: Bool {
        isMemberSearchFocused
            || !memberSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filteredFriends: [UserSummary] {
        let available = friends.filter { !selectedMemberIds.contains($0.id) }
        let query = memberSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return available }
        return available.filter {
            $0.displayName.lowercased().contains(query)
                || $0.username.lowercased().contains(query)
        }
    }

    func addMember(_ friend: UserSummary) {
        selectedMemberIds.insert(friend.id)
    }

    func removeMember(_ friend: UserSummary) {
        selectedMemberIds.remove(friend.id)
    }

    func setMemberSearchFocused(_ focused: Bool) {
        isMemberSearchFocused = focused
    }

    func loadFriendsIfNeeded() async {
        guard friends.isEmpty else { return }
        await loadFriends()
    }

    func loadFriends() async {
        guard !isLoadingFriends else { return }

        isLoadingFriends = true
        friendsLoadErrorMessage = nil
        defer { isLoadingFriends = false }

        do {
            friends = try await fetchMyFriendsUseCase.execute()
            selectedMemberIds.formIntersection(Set(friends.map(\.id)))
        } catch {
            friendsLoadErrorMessage = languageService.localizedMessage(for: error)
        }
    }

    func onPhotoItemChanged() async {
        guard let selectedPhotoItem else {
            previewImage = nil
            return
        }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) else {
            errorMessage = languageService.text(.friendsImageLoadFailed)
            return
        }
        previewImage = UIImage(data: data)
    }

    func create() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = languageService.text(.friendsGroupNameRequired)
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        let description = groupDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var group = try await createGroupUseCase.execute(
                name: trimmedName,
                description: description.isEmpty ? nil : description
            )

            var warnings: [String] = []

            if let previewImage {
                do {
                    let upload = try await uploadGroupAvatarUseCase.execute(
                        image: previewImage,
                        groupId: group.id
                    )
                    group = try await updateGroupAvatarUseCase.execute(
                        groupId: group.id,
                        avatarURL: upload.url.absoluteString
                    )
                } catch {
                    warnings.append(languageService.text(.friendsGroupAvatarUploadFailed))
                }
            }

            let memberIds = Array(selectedMemberIds)
            if !memberIds.isEmpty {
                do {
                    let result = try await inviteFriendsUseCase.execute(
                        groupId: group.id,
                        userIds: memberIds
                    )
                    if result.invited.isEmpty, !result.skipped.isEmpty {
                        warnings.append(languageService.text(.friendsInviteSelectedFailed))
                    } else if !result.skipped.isEmpty {
                        warnings.append(languageService.text(.friendsInvitePartialSkipped))
                    }
                } catch {
                    warnings.append(languageService.text(.friendsInviteFailed))
                }
            }

            try? await openLinkedGroupConversation(group.id, group.name, memberIds)

            let invitedMemberIds = memberIds
            resetForm()
            let createdMessage = languageService.format(.friendsGroupCreated, group.name)
            if warnings.isEmpty {
                successMessage = createdMessage
            } else {
                successMessage = "\(createdMessage) \(warnings.joined(separator: " "))"
            }
            onSuccess(group, invitedMemberIds)
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }

    private func resetForm() {
        name = ""
        groupDescription = ""
        selectedPhotoItem = nil
        previewImage = nil
        selectedMemberIds = []
        memberSearchQuery = ""
        isMemberSearchFocused = false
    }
}
