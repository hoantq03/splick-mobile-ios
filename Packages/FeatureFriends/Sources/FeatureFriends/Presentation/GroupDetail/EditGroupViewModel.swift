import Foundation
import SwiftUI
import PhotosUI
import UIKit
import Common
import FeatureMedia
import SplickDomain

@MainActor
final class EditGroupViewModel: ObservableObject {
    @Published var name: String
    @Published var description: String
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var previewImage: UIImage?
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let groupId: UUID
    private let updateGroupUseCase: UpdateGroupUseCaseProtocol
    private let updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol
    private let uploadMediaUseCase: UploadMediaUseCaseProtocol

    init(
        group: SplickDomain.Group,
        updateGroupUseCase: UpdateGroupUseCaseProtocol,
        updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol,
        uploadMediaUseCase: UploadMediaUseCaseProtocol
    ) {
        self.groupId = group.id
        self.name = group.name
        self.description = group.description ?? ""
        self.updateGroupUseCase = updateGroupUseCase
        self.updateGroupAvatarUseCase = updateGroupAvatarUseCase
        self.uploadMediaUseCase = uploadMediaUseCase
    }

    func onPhotoItemChanged() async {
        guard let selectedPhotoItem else {
            previewImage = nil
            return
        }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) else {
            errorMessage = "Không tải được ảnh."
            return
        }
        previewImage = UIImage(data: data)
    }

    func save() async -> SplickDomain.Group? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = FriendsError.invalidGroupName.localizedDescription
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptionValue = trimmedDescription.isEmpty ? nil : trimmedDescription
            var updated = try await updateGroupUseCase.execute(
                groupId: groupId,
                name: trimmedName,
                description: descriptionValue
            )

            if let previewImage,
               let jpeg = previewImage.jpegData(compressionQuality: 0.85) {
                let upload = try await uploadMediaUseCase.execute(imageData: jpeg)
                updated = try await updateGroupAvatarUseCase.execute(
                    groupId: groupId,
                    avatarURL: upload.url.absoluteString
                )
            }

            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
