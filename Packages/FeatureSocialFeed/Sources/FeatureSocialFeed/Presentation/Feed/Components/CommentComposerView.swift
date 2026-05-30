import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import DesignSystem
import SplickDomain

struct CommentComposerView: View {
    let placeholder: String
    let onSubmit: (String, [CommentSubmissionAttachment]) -> Void
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?

    @State private var draft = ""
    @State private var pendingAttachments: [CommentSubmissionAttachment] = []
    @State private var validationMessage: String?
    @State private var showMentionPicker = false
    @State private var activeMentionQuery = ""
    @State private var mentionViewModel: MentionFriendsViewModel?
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false

    private let composerHeight: CGFloat = 36

    init(
        placeholder: String,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        onSubmit: @escaping (String, [CommentSubmissionAttachment]) -> Void
    ) {
        self.placeholder = placeholder
        self.fetchFriendsUseCase = fetchFriendsUseCase
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
                    if fetchFriendsUseCase != nil {
                        Button {
                            draft += draft.isEmpty || draft.last?.isWhitespace == true ? "@" : " @"
                            syncMentionPicker(with: draft)
                        } label: {
                            Text("@")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                .frame(width: 28, height: composerHeight)
                        }
                    }

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
                }

                TextField(placeholder, text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(minHeight: composerHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    )
                    .submitLabel(.send)
                    .onSubmit(submit)
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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .data, .item],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
        }
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
                sizeBytes: $0.data.count
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
            CommentAttachment(kind: $0.kind, fileName: $0.fileName, sizeBytes: $0.data.count)
        }
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
        }
    }
}
