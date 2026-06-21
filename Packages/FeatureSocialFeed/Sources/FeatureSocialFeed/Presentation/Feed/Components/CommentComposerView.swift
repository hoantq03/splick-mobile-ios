import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Common
import DesignSystem
import Localization
import SplickDomain
import FeatureStickers

struct CommentComposerView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies

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
    @State private var pendingAttachments: [CommentSubmissionAttachment] = []
    @State private var validationMessage: String?
    @State private var showMentionPicker = false
    @State private var activeMentionQuery = ""
    @State private var mentionViewModel: MentionFriendsViewModel?
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var showGifPicker = false
    @State private var showEmojiInsertPicker = false
    @State private var showCustomEmojiUpload = false

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

            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(pendingAttachments.enumerated()), id: \.offset) { index, item in
                            attachmentChip(item, index: index)
                        }
                    }
                }
            }

            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 2) {
                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: 10,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(width: 28, height: composerHeight)
                    }
                    .onChange(of: photoPickerItems) { items in
                        Task { await importPhotoPickerItems(items) }
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 14))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(width: 28, height: composerHeight)
                    }

                    if gifPickerViewModel != nil || groupId != nil {
                        emojiMenuButton
                    }
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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .data, .item],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
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
                            Button("Đóng") { showGifPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showEmojiInsertPicker) {
            EmojiPickerSheet(
                groupId: groupId,
                mode: .inlineInsert,
                onPick: { emoji in insertEmoji(emoji) },
                onOpenUpload: groupId != nil ? { openCustomEmojiUpload() } : nil
            )
        }
        .sheet(isPresented: $showCustomEmojiUpload) {
            if let groupId, let deps = customEmojiDependencies {
                CustomEmojiUploadSheet(
                    groupId: groupId,
                    currentUserId: nil,
                    customEmojiFetcher: deps.fetcher,
                    uploadMediaUseCase: deps.uploadMediaUseCase,
                    addEmojiUseCase: deps.addEmojiUseCase,
                    deleteEmojiUseCase: deps.deleteEmojiUseCase
                )
            }
        }
    }

    private func openCustomEmojiUpload() {
        showEmojiInsertPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showCustomEmojiUpload = true
        }
    }

    @ViewBuilder
    private var emojiMenuButton: some View {
        let showsGif = gifPickerViewModel != nil
        let showsEmoji = groupId != nil || showsGif

        if showsGif && showsEmoji {
            Menu {
                if showsGif {
                    Button {
                        showGifPicker = true
                    } label: {
                        Label("GIF", systemImage: "photo.on.rectangle.angled")
                    }
                }
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
        } else if showsGif {
            Button {
                showGifPicker = true
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

    private func attachmentChip(_ item: CommentSubmissionAttachment, index: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconName(for: item.kind))
                .font(.system(size: 10))
            Text(item.fileName ?? item.kind.rawValue)
                .font(.system(size: 10))
                .lineLimit(1)
            Button {
                pendingAttachments.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(SplickTheme.Colors.tertiaryBackground))
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let previewAttachments = pendingAttachments.map {
            CommentAttachment(
                kind: $0.kind,
                fileName: $0.fileName,
                sizeBytes: $0.data?.count ?? 0
            )
        }
        if let error = CommentAttachmentValidator.validate(previewAttachments) {
            validationMessage = error
            return
        }
        guard canSubmit else { return }
        validationMessage = nil
        onSubmit(text, pendingAttachments)
        draft = ""
        pendingAttachments = []
        photoPickerItems = []
        showMentionPicker = false
        appliedPrefillUsername = nil
    }

    @MainActor
    private func importPhotoPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let kind: CommentAttachmentKind = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })
                ? .video
                : .image
            let mimeType = kind == .video ? "video/mp4" : "image/jpeg"
            let submission = CommentSubmissionAttachment(
                kind: kind,
                data: data,
                mimeType: mimeType,
                fileName: kind == .video ? "video.mp4" : "photo.jpg"
            )
            if let error = CommentAttachmentValidator.canAdd(
                CommentAttachment(kind: kind, sizeBytes: data.count),
                to: previewAttachments(from: pendingAttachments)
            ) {
                validationMessage = error
                continue
            }
            validationMessage = nil
            pendingAttachments.append(submission)
        }
        photoPickerItems = []
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            let submission = CommentSubmissionAttachment(
                kind: .file,
                data: data,
                mimeType: mimeType(for: url),
                fileName: url.lastPathComponent
            )
            if let error = CommentAttachmentValidator.canAdd(
                CommentAttachment(kind: .file, fileName: url.lastPathComponent, sizeBytes: data.count),
                to: previewAttachments(from: pendingAttachments)
            ) {
                validationMessage = error
                continue
            }
            validationMessage = nil
            pendingAttachments.append(submission)
        }
    }

    private func previewAttachments(from submissions: [CommentSubmissionAttachment]) -> [CommentAttachment] {
        submissions.map {
            CommentAttachment(kind: $0.kind, fileName: $0.fileName, sizeBytes: $0.data?.count ?? 0)
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
            to: previewAttachments(from: pendingAttachments)
        ) {
            validationMessage = error
            return
        }
        validationMessage = nil
        pendingAttachments.append(submission)
    }

    private func mimeType(for url: URL) -> String {
        if url.pathExtension.lowercased() == "pdf" {
            return "application/pdf"
        }
        return "application/octet-stream"
    }

    private func iconName(for kind: CommentAttachmentKind) -> String {
        switch kind {
        case .image: return "photo"
        case .video: return "video"
        case .file: return "doc"
        case .gif: return "face.smiling"
        }
    }
}
