import Foundation
import SwiftUI
import PhotosUI
import UIKit
import Common
import SplickDomain

@MainActor
public enum AttachmentDraftImporter {
    public typealias UploadHandler = @Sendable (Data, String) async throws -> UploadedMediaReference
    public typealias DraftMutator = (inout CommentAttachmentDraft) -> Void

    public static func beginImportingPhotoPickerItems(
        _ items: [PhotosPickerItem],
        currentDrafts: [CommentAttachmentDraft],
        maxRemainingImageSlots: Int,
        uploadHandler: UploadHandler?,
        appendDraft: @escaping (CommentAttachmentDraft) -> Void,
        updateDraft: @escaping (UUID, @escaping DraftMutator) -> Void,
        onValidationError: @escaping (String) -> Void
    ) {
        guard !items.isEmpty else { return }

        var drafts = currentDrafts
        for item in items {
            guard remainingImageSlots(in: drafts, maximumImages: maxRemainingImageSlots) > 0 else { break }
            let draft = CommentAttachmentDraft(
                id: UUID(),
                kind: .image,
                phase: .loading,
                previewImage: nil,
                submission: nil
            )
            drafts.append(draft)
            appendDraft(draft)
            let draftId = draft.id
            Task {
                await processPhotoPickerItem(
                    item,
                    draftId: draftId,
                    uploadHandler: uploadHandler,
                    snapshotDrafts: { drafts },
                    updateDraft: updateDraft,
                    onValidationError: onValidationError
                )
            }
        }
    }

    public static func remainingImageSlots(in drafts: [CommentAttachmentDraft], maximumImages: Int) -> Int {
        let imageCount = drafts.filter { $0.kind == .image }.count
        return Swift.max(0, maximumImages - imageCount)
    }

    public static func processPhotoPickerItem(
        _ item: PhotosPickerItem,
        draftId: UUID,
        uploadHandler: UploadHandler?,
        snapshotDrafts: @MainActor @escaping () -> [CommentAttachmentDraft],
        updateDraft: @MainActor @escaping (UUID, @escaping DraftMutator) -> Void,
        onValidationError: @MainActor @escaping (String) -> Void
    ) async {
        let prepared = await Task.detached(priority: .userInitiated) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)?.normalizedOrientation(),
                  let jpegData = image.jpegData(compressionQuality: 0.92) else {
                return nil as (UIImage, Data)?
            }
            return (image, jpegData)
        }.value

        let drafts = snapshotDrafts()
        guard drafts.contains(where: { $0.id == draftId }) else { return }

        guard let (image, jpegData) = prepared else {
            markDraft(
                draftId,
                phase: .failed("Không thể mở ảnh đã chọn."),
                updateDraft: updateDraft,
                onValidationError: onValidationError
            )
            return
        }

        updateDraft(draftId) { $0.previewImage = image }

        let candidate = CommentAttachment(kind: .image, sizeBytes: jpegData.count)
        let currentDrafts = snapshotDrafts()
        if let error = CommentAttachmentValidator.canAdd(
            candidate,
            to: previewAttachmentModelsIncludingPending(from: draftId, drafts: currentDrafts)
        ) {
            markDraft(
                draftId,
                phase: .failed(error),
                updateDraft: updateDraft,
                onValidationError: onValidationError
            )
            return
        }

        let imageIndex = currentDrafts.filter { $0.kind == .image }.count

        if let uploadHandler {
            do {
                let upload = try await uploadHandler(jpegData, "image/jpeg")
                let fileName = "photo-\(imageIndex).jpg"
                let submission = CommentSubmissionAttachment(
                    kind: .image,
                    uploadedMediaId: upload.id,
                    url: upload.url,
                    thumbnailURL: upload.thumbnailURL,
                    sizeBytes: upload.sizeBytes,
                    fileName: fileName
                )
                markDraft(
                    draftId,
                    phase: .ready,
                    previewImage: image,
                    submission: submission,
                    updateDraft: updateDraft,
                    onValidationError: onValidationError
                )
            } catch {
                markDraft(
                    draftId,
                    phase: .failed(error.localizedDescription),
                    updateDraft: updateDraft,
                    onValidationError: onValidationError
                )
            }
            return
        }

        let submission = CommentSubmissionAttachment(
            kind: .image,
            data: jpegData,
            mimeType: "image/jpeg",
            fileName: "photo-\(imageIndex).jpg"
        )
        markDraft(
            draftId,
            phase: .ready,
            previewImage: image,
            submission: submission,
            updateDraft: updateDraft,
            onValidationError: onValidationError
        )
    }

    public static func readySubmissions(from drafts: [CommentAttachmentDraft]) -> [CommentSubmissionAttachment] {
        drafts.compactMap { draft in
            guard draft.phase == .ready else { return nil }
            return draft.submission
        }
    }

    private static func previewAttachmentModelsIncludingPending(
        from excludingDraftId: UUID,
        drafts: [CommentAttachmentDraft]
    ) -> [CommentAttachment] {
        var models = CommentAttachmentValidator.previewModels(from: readySubmissions(from: drafts))
        let pendingImages = drafts.filter {
            $0.kind == .image && $0.id != excludingDraftId && $0.phase == .loading
        }
        models.append(contentsOf: pendingImages.map { _ in CommentAttachment(kind: .image, sizeBytes: 0) })
        return models
    }

    private static func markDraft(
        _ draftId: UUID,
        phase: CommentAttachmentDraft.Phase,
        previewImage: UIImage? = nil,
        submission: CommentSubmissionAttachment? = nil,
        updateDraft: @escaping (UUID, @escaping DraftMutator) -> Void,
        onValidationError: @escaping (String) -> Void
    ) {
        updateDraft(draftId) { draft in
            draft.phase = phase
            if let previewImage {
                draft.previewImage = previewImage
            }
            if let submission {
                draft.submission = submission
            }
            if case .failed = phase, let message = draft.phase.failureMessage {
                onValidationError(message)
            }
        }
    }
}
