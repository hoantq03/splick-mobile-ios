import SwiftUI
import PhotosUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain
import FeatureStickers

struct CommentComposerView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @Environment(\.commentImageUpload) private var commentImageUpload

    let placeholder: String
    /// When set (e.g. user tapped Reply), pre-fills `@username ` for mention + server push.
    let prefillMentionUsername: String?
    let groupId: UUID?
    @Binding var isFocused: Bool
    let onSubmit: (String, [CommentSubmissionAttachment]) -> Void
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    private let gifPickerViewModel: GifPickerViewModel?

    @State private var draft = ""
    @State private var appliedPrefillUsername: String?
    @State private var attachmentDrafts: [CommentAttachmentDraft] = []
    @State private var validationMessage: String?
    @State private var showMentionPicker = false
    @State private var activeMentionQuery = ""
    @State private var mentionViewModel: MentionFriendsViewModel?
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showGifPicker = false
    @State private var showEmojiInsertPicker = false
    @State private var showCustomEmojiUpload = false
    @State private var attachmentPreviewRoute: LocalImagePreviewRoute?

    private let composerHeight: CGFloat = 36

    init(
        placeholder: String,
        prefillMentionUsername: String? = nil,
        isFocused: Binding<Bool> = .constant(false),
        groupId: UUID? = nil,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        gifPickerViewModel: GifPickerViewModel? = nil,
        onSubmit: @escaping (String, [CommentSubmissionAttachment]) -> Void
    ) {
        self.placeholder = placeholder
        self.prefillMentionUsername = prefillMentionUsername
        _isFocused = isFocused
        self.groupId = groupId
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.gifPickerViewModel = gifPickerViewModel
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(SplickTheme.Colors.error)
            }

            if showMentionPicker, let mentionViewModel {
                MentionPickerPopup(viewModel: mentionViewModel) { user in
                    insertMention(user)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !attachmentDrafts.isEmpty {
                CommentAttachmentDraftStrip(
                    drafts: attachmentDrafts,
                    onTapDraft: { index in
                        attachmentPreviewRoute = LocalImagePreviewRoute(index: index)
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
                            .font(.system(size: 14))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(width: 28, height: composerHeight)
                    }
                    .disabled(remainingImageSlots == 0)
                    .onChange(of: photoPickerItems) { items in
                        beginImportingPhotoPickerItems(items)
                    }

                    emojiMenuButton
                }

                MentionTextField(
                    placeholder,
                    text: $draft,
                    isFocused: $isFocused,
                    fontSize: 13,
                    minHeight: composerHeight
                )
                .frame(minHeight: composerHeight)
                .layoutPriority(1)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(SplickTheme.Colors.tertiaryBackground)
                )
                .onChange(of: draft) { newValue in
                    syncMentionPicker(with: newValue)
                }

                Button(action: submit) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            canSubmit
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.textTertiary
                        )
                        .frame(width: composerHeight, height: composerHeight)
                }
                .disabled(!canSubmit)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showMentionPicker)
        .onChange(of: prefillMentionUsername) { username in
            applyPrefillMention(username)
        }
        .onAppear {
            applyPrefillMention(prefillMentionUsername)
        }
        .sheet(isPresented: $showEmojiInsertPicker) {
            EmojiPickerSheet(
                currentUserId: nil,
                mode: .inlineInsert,
                onPick: { emoji in insertEmoji(emoji) },
                onOpenUpload: { openCustomEmojiUpload() }
            )
        }
        .sheet(isPresented: $showCustomEmojiUpload) {
            if let deps = customEmojiDependencies {
                CustomEmojiUploadSheet(
                    currentUserId: nil,
                    customEmojiFetcher: deps.fetcher,
                    uploadMediaUseCase: deps.uploadMediaUseCase,
                    addEmojiUseCase: deps.addEmojiUseCase,
                    deleteEmojiUseCase: deps.deleteEmojiUseCase
                )
            }
        }
        .sheet(isPresented: $showGifPicker) {
            if let gifPickerViewModel {
                NavigationStack {
                    GifPickerView(viewModel: gifPickerViewModel) { sticker in
                        appendGifSticker(sticker)
                        showGifPicker = false
                    }
                    .navigationTitle("Chọn GIF")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(languageService.text(.commonCancel)) { showGifPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(item: $attachmentPreviewRoute) { route in
            attachmentFullscreenPreview(at: route.index)
        }
    }

    @ViewBuilder
    private var emojiMenuButton: some View {
        if gifPickerViewModel != nil {
            Menu {
                Button {
                    showGifPicker = true
                } label: {
                    Label("GIF", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(remainingGifSlots == 0)

                Button {
                    showEmojiInsertPicker = true
                } label: {
                    Label(languageService.text(.feedEmojiPickerTitle), systemImage: "face.smiling")
                }
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 14))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(width: 28, height: composerHeight)
            }
        } else {
            Button {
                showEmojiInsertPicker = true
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 14))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(width: 28, height: composerHeight)
            }
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
        let imageCount = attachmentDrafts.filter { $0.kind == .image }.count
        return max(0, CommentAttachmentValidator.maxImages - imageCount)
    }

    private var remainingGifSlots: Int {
        let gifCount = attachmentDrafts.filter { $0.kind == .gif }.count
        return max(0, CommentAttachmentValidator.maxGifs - gifCount)
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

    private func openCustomEmojiUpload() {
        showEmojiInsertPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showCustomEmojiUpload = true
        }
    }

    private func applyPrefillMention(_ username: String?) {
        guard let username, !username.isEmpty else {
            appliedPrefillUsername = nil
            return
        }
        let mention = "@\(username) "
        appliedPrefillUsername = username
        guard draft != mention else { return }
        draft = mention
        syncMentionPicker(with: draft)
    }

    private func syncMentionPicker(with text: String) {
        guard fetchFriendsUseCase != nil else {
            showMentionPicker = false
            return
        }

        if let context = MentionContext.active(in: text) {
            if mentionViewModel == nil, let useCase = fetchFriendsUseCase {
                mentionViewModel = MentionFriendsViewModel(useCase: useCase)
            }
            let openingPicker = !showMentionPicker
            showMentionPicker = true
            if openingPicker || context.query != activeMentionQuery {
                activeMentionQuery = context.query
                mentionViewModel?.reset(query: context.query)
            }
        } else {
            showMentionPicker = false
            activeMentionQuery = ""
        }
    }

    private func insertMention(_ user: UserSummary) {
        guard let context = MentionContext.active(in: draft) else { return }
        let mention = "@\(user.username) "
        draft.replaceSubrange(context.replaceRange, with: mention)
        showMentionPicker = false
        activeMentionQuery = ""
    }

    private func insertEmoji(_ emoji: String) {
        let token = EmojiKind.from(emoji).storageValue
        if draft.isEmpty || draft.last?.isWhitespace == true {
            draft += token
        } else {
            draft += " \(token)"
        }
    }

    private var canSubmit: Bool {
        guard !isProcessingAttachments, !hasFailedAttachments else { return false }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasReadyAttachments = attachmentDrafts.contains { $0.phase == .ready && $0.submission != nil }
        return !trimmed.isEmpty || hasReadyAttachments
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let submissions = readySubmissions
        let previewAttachmentModels = submissions.map {
            CommentAttachment(kind: $0.kind, fileName: $0.fileName, sizeBytes: $0.uploadedSizeBytes ?? $0.data?.count ?? 0)
        }
        if let error = CommentAttachmentValidator.validate(previewAttachmentModels) {
            validationMessage = error
            return
        }
        guard canSubmit else { return }
        validationMessage = nil
        onSubmit(text, submissions)
        draft = ""
        attachmentDrafts = []
        photoPickerItems = []
        showMentionPicker = false
        appliedPrefillUsername = nil
    }

    private var readySubmissions: [CommentSubmissionAttachment] {
        attachmentDrafts.compactMap { draft in
            guard draft.phase == .ready else { return nil }
            return draft.submission
        }
    }

    private func removeDraft(at index: Int) {
        guard attachmentDrafts.indices.contains(index) else { return }
        attachmentDrafts.remove(at: index)
        if let route = attachmentPreviewRoute, route.index >= attachmentDrafts.count {
            attachmentPreviewRoute = nil
        }
    }

    private func appendGifSticker(_ sticker: Sticker) {
        let submission = CommentSubmissionAttachment(
            kind: .gif,
            remoteURL: sticker.url,
            fileName: "gif-\(sticker.id).gif"
        )
        if let error = CommentAttachmentValidator.canAdd(
            CommentAttachment(kind: .gif, fileName: submission.fileName),
            to: previewAttachmentModels(from: readySubmissions)
        ) {
            validationMessage = error
            return
        }
        validationMessage = nil
        attachmentDrafts.append(
            CommentAttachmentDraft(
                id: UUID(),
                kind: .gif,
                phase: .ready,
                previewImage: nil,
                submission: submission
            )
        )
    }

    private func beginImportingPhotoPickerItems(_ items: [PhotosPickerItem]) {
        photoPickerItems = []
        guard !items.isEmpty else { return }

        for item in items {
            guard remainingImageSlots > 0 else { break }
            let draft = CommentAttachmentDraft(
                id: UUID(),
                kind: .image,
                phase: .loading,
                previewImage: nil,
                submission: nil
            )
            attachmentDrafts.append(draft)
            let draftId = draft.id
            Task {
                await processPhotoPickerItem(item, draftId: draftId)
            }
        }
    }

    @MainActor
    private func processPhotoPickerItem(_ item: PhotosPickerItem, draftId: UUID) async {
        let prepared = await Task.detached(priority: .userInitiated) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)?.normalizedOrientation(),
                  let jpegData = image.jpegData(compressionQuality: 0.92) else {
                return nil as (UIImage, Data)?
            }
            return (image, jpegData)
        }.value

        guard attachmentDrafts.contains(where: { $0.id == draftId }) else { return }

        guard let (image, jpegData) = prepared else {
            markDraft(draftId, phase: .failed("Không thể mở ảnh đã chọn."))
            return
        }

        updateDraftPreview(draftId, previewImage: image)

        let candidate = CommentAttachment(kind: .image, sizeBytes: jpegData.count)
        if let error = CommentAttachmentValidator.canAdd(
            candidate,
            to: previewAttachmentModelsIncludingPending(from: draftId)
        ) {
            markDraft(draftId, phase: .failed(error))
            return
        }

        if let commentImageUpload {
            do {
                let upload = try await commentImageUpload(jpegData, "image/jpeg")
                let fileName = "photo-\(imageDraftCount).jpg"
                let submission = CommentSubmissionAttachment(
                    kind: .image,
                    uploadedMediaId: upload.id,
                    url: upload.url,
                    thumbnailURL: upload.thumbnailURL,
                    sizeBytes: upload.sizeBytes,
                    fileName: fileName
                )
                markDraft(draftId, phase: .ready, previewImage: image, submission: submission)
            } catch {
                markDraft(draftId, phase: .failed(error.localizedDescription))
            }
            return
        }

        let submission = CommentSubmissionAttachment(
            kind: .image,
            data: jpegData,
            mimeType: "image/jpeg",
            fileName: "photo-\(imageDraftCount).jpg"
        )
        markDraft(draftId, phase: .ready, previewImage: image, submission: submission)
    }

    private var imageDraftCount: Int {
        attachmentDrafts.filter { $0.kind == .image }.count
    }

    @MainActor
    private func updateDraftPreview(_ draftId: UUID, previewImage: UIImage) {
        guard let index = attachmentDrafts.firstIndex(where: { $0.id == draftId }) else { return }
        attachmentDrafts[index].previewImage = previewImage
    }

    @MainActor
    private func markDraft(
        _ draftId: UUID,
        phase: CommentAttachmentDraft.Phase,
        previewImage: UIImage? = nil,
        submission: CommentSubmissionAttachment? = nil
    ) {
        guard let index = attachmentDrafts.firstIndex(where: { $0.id == draftId }) else { return }
        attachmentDrafts[index].phase = phase
        if let previewImage {
            attachmentDrafts[index].previewImage = previewImage
        }
        if let submission {
            attachmentDrafts[index].submission = submission
        }
        if case .failed = phase {
            validationMessage = attachmentDrafts[index].phase.failureMessage
        } else if !hasFailedAttachments {
            validationMessage = nil
        }
    }

    private func previewAttachmentModels(from submissions: [CommentSubmissionAttachment]) -> [CommentAttachment] {
        submissions.map {
            CommentAttachment(kind: $0.kind, fileName: $0.fileName, sizeBytes: $0.uploadedSizeBytes ?? $0.data?.count ?? 0)
        }
    }

    private func previewAttachmentModelsIncludingPending(from excludingDraftId: UUID) -> [CommentAttachment] {
        var models = previewAttachmentModels(from: readySubmissions)
        let pendingImages = attachmentDrafts.filter {
            $0.kind == .image && $0.id != excludingDraftId && $0.phase == .loading
        }
        models.append(contentsOf: pendingImages.map { _ in CommentAttachment(kind: .image, sizeBytes: 0) })
        return models
    }
}

private extension CommentAttachmentDraft.Phase {
    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
