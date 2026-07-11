import SwiftUI
import PhotosUI
import Common
import SplickDomain

public struct AttachmentComposerConfiguration {
    public var maxImages: Int
    public var maxGifs: Int
    public var photoIconSize: CGFloat
    public var composerHeight: CGFloat
    public var forbiddenSubmissionKinds: Set<CommentAttachmentKind>
    public var forbiddenKindMessage: (CommentAttachmentKind) -> String?

    public init(
        maxImages: Int = CommentAttachmentValidator.maxImages,
        maxGifs: Int = CommentAttachmentValidator.maxGifs,
        photoIconSize: CGFloat = 14,
        composerHeight: CGFloat = 36,
        forbiddenSubmissionKinds: Set<CommentAttachmentKind> = [],
        forbiddenKindMessage: ((CommentAttachmentKind) -> String?)? = nil
    ) {
        self.maxImages = maxImages
        self.maxGifs = maxGifs
        self.photoIconSize = photoIconSize
        self.composerHeight = composerHeight
        self.forbiddenSubmissionKinds = forbiddenSubmissionKinds
        self.forbiddenKindMessage = forbiddenKindMessage ?? { _ in nil }
    }
}

public struct AttachmentComposerView<TextField: View, Accessory: View, SendButton: View>: View {
    @Environment(\.imageAttachmentUpload) private var imageAttachmentUpload

    @Binding var text: String
    @Binding var attachmentDrafts: [CommentAttachmentDraft]
    @Binding var validationMessage: String?
    @Binding var isFocused: Bool

    let configuration: AttachmentComposerConfiguration
    let isExternallyDisabled: Bool
    let onSend: (String, [CommentSubmissionAttachment]) -> Void
    @ViewBuilder let textField: () -> TextField
    @ViewBuilder let accessoryAfterPhoto: () -> Accessory
    @ViewBuilder let sendButton: () -> SendButton

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var attachmentPreviewRoute: AttachmentPreviewRoute?

    public init(
        text: Binding<String>,
        attachmentDrafts: Binding<[CommentAttachmentDraft]>,
        validationMessage: Binding<String?>,
        isFocused: Binding<Bool>,
        configuration: AttachmentComposerConfiguration = AttachmentComposerConfiguration(),
        isExternallyDisabled: Bool = false,
        onSend: @escaping (String, [CommentSubmissionAttachment]) -> Void,
        @ViewBuilder textField: @escaping () -> TextField,
        @ViewBuilder accessoryAfterPhoto: @escaping () -> Accessory,
        @ViewBuilder sendButton: @escaping () -> SendButton
    ) {
        _text = text
        _attachmentDrafts = attachmentDrafts
        _validationMessage = validationMessage
        _isFocused = isFocused
        self.configuration = configuration
        self.isExternallyDisabled = isExternallyDisabled
        self.onSend = onSend
        self.textField = textField
        self.accessoryAfterPhoto = accessoryAfterPhoto
        self.sendButton = sendButton
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(SplickTheme.Colors.error)
            }

            if !attachmentDrafts.isEmpty {
                AttachmentDraftStrip(
                    drafts: attachmentDrafts,
                    onTapDraft: { index in
                        attachmentPreviewRoute = AttachmentPreviewRoute(index: index)
                    },
                    onRemoveDraft: { index in
                        removeDraft(at: index)
                    }
                )
            }

            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 2) {
                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: remainingImageSlots,
                        matching: .images
                    ) {
                        Image(systemName: "photo")
                            .font(.system(size: configuration.photoIconSize))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(width: 28, height: configuration.composerHeight)
                    }
                    .disabled(remainingImageSlots == 0 || isExternallyDisabled)
                    .onChange(of: photoPickerItems) { items in
                        beginImportingPhotoPickerItems(items)
                    }

                    accessoryAfterPhoto()
                }

                textField()
                    .frame(minHeight: configuration.composerHeight)
                    .layoutPriority(1)

                Button(action: submit) {
                    sendButton()
                }
                .disabled(!canSubmit)
            }
        }
        .fullScreenCover(item: $attachmentPreviewRoute) { route in
            attachmentFullscreenPreview(at: route.index)
        }
    }

    @ViewBuilder
    private func attachmentFullscreenPreview(at index: Int) -> some View {
        if attachmentDrafts.indices.contains(index) {
            let draft = attachmentDrafts[index]
            if draft.phase == .ready {
                switch draft.kind {
                case .image:
                    if let image = draft.previewImage {
                        LocalImageFullscreenPreview(
                            images: [image],
                            initialIndex: 0,
                            onDismiss: { attachmentPreviewRoute = nil }
                        )
                    }
                case .gif:
                    if let url = draft.submission?.remoteURL {
                        RemoteGifFullscreenPreview(url: url) {
                            attachmentPreviewRoute = nil
                        }
                    }
                default:
                    EmptyView()
                }
            }
        }
    }

    private var remainingImageSlots: Int {
        AttachmentDraftImporter.remainingImageSlots(in: attachmentDrafts, maximumImages: configuration.maxImages)
    }

    private var isProcessingAttachments: Bool {
        attachmentDrafts.contains { $0.phase == .loading }
    }

    private var hasFailedAttachments: Bool {
        attachmentDrafts.contains {
            if case .failed = $0.phase { return true }
            return false
        }
    }

    public var canSubmit: Bool {
        guard !isExternallyDisabled, !isProcessingAttachments, !hasFailedAttachments else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasReadyAttachments = attachmentDrafts.contains { $0.phase == .ready && $0.submission != nil }
        return !trimmed.isEmpty || hasReadyAttachments
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let submissions = AttachmentDraftImporter.readySubmissions(from: attachmentDrafts)

        for submission in submissions {
            if configuration.forbiddenSubmissionKinds.contains(submission.kind),
               let message = configuration.forbiddenKindMessage(submission.kind) {
                validationMessage = message
                return
            }
        }

        let previewAttachmentModels = CommentAttachmentValidator.previewModels(from: submissions)
        if let error = CommentAttachmentValidator.validate(previewAttachmentModels) {
            validationMessage = error
            return
        }
        guard canSubmit else { return }
        validationMessage = nil
        onSend(trimmed, submissions)
        text = ""
        attachmentDrafts = []
        photoPickerItems = []
    }

    private func removeDraft(at index: Int) {
        guard attachmentDrafts.indices.contains(index) else { return }
        attachmentDrafts.remove(at: index)
        if let route = attachmentPreviewRoute, route.index >= attachmentDrafts.count {
            attachmentPreviewRoute = nil
        }
        if !hasFailedAttachments {
            validationMessage = nil
        }
    }

    private func beginImportingPhotoPickerItems(_ items: [PhotosPickerItem]) {
        photoPickerItems = []
        guard !items.isEmpty else { return }

        AttachmentDraftImporter.beginImportingPhotoPickerItems(
            items,
            currentDrafts: attachmentDrafts,
            maxRemainingImageSlots: configuration.maxImages,
            uploadHandler: imageAttachmentUpload,
            appendDraft: { draft in
                attachmentDrafts.append(draft)
            },
            updateDraft: { draftId, mutate in
                guard let index = attachmentDrafts.firstIndex(where: { $0.id == draftId }) else { return }
                mutate(&attachmentDrafts[index])
            },
            onValidationError: { message in
                validationMessage = message
            }
        )
    }
}
