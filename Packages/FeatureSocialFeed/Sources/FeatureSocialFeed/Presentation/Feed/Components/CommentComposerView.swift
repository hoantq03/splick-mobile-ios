import SwiftUI
import DesignSystem
import SplickDomain

struct CommentComposerView: View {
    let placeholder: String
    let onSubmit: (String, [CommentAttachment]) -> Void
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?

    @State private var draft = ""
    @State private var pendingAttachments: [CommentAttachment] = []
    @State private var validationMessage: String?
    @State private var showMentionPicker = false
    @State private var activeMentionQuery = ""
    @State private var mentionViewModel: MentionFriendsViewModel?

    private let composerHeight: CGFloat = 36

    init(
        placeholder: String,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        onSubmit: @escaping (String, [CommentAttachment]) -> Void
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
                        ForEach(pendingAttachments) { item in
                            attachmentChip(item)
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
                    attachButton(icon: "photo", kind: .image, mockSize: 800_000)
                    attachButton(icon: "video", kind: .video, mockSize: 12_000_000)
                    attachButton(icon: "paperclip", kind: .file, mockSize: 500_000)
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

    private func attachButton(icon: String, kind: CommentAttachmentKind, mockSize: Int) -> some View {
        Button {
            let attachment = mockAttachment(kind: kind, size: mockSize)
            if let error = CommentAttachmentValidator.canAdd(attachment, to: pendingAttachments) {
                validationMessage = error
            } else {
                validationMessage = nil
                pendingAttachments.append(attachment)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: 28, height: composerHeight)
        }
    }

    private func attachmentChip(_ item: CommentAttachment) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconName(for: item.kind))
                .font(.system(size: 10))
            Text(item.fileName ?? item.kind.rawValue)
                .font(.system(size: 10))
                .lineLimit(1)
            Button {
                pendingAttachments.removeAll { $0.id == item.id }
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
        if let error = CommentAttachmentValidator.validate(pendingAttachments) {
            validationMessage = error
            return
        }
        guard canSubmit else { return }
        validationMessage = nil
        onSubmit(text.isEmpty ? "" : text, pendingAttachments)
        draft = ""
        pendingAttachments = []
        showMentionPicker = false
    }

    private func mockAttachment(kind: CommentAttachmentKind, size: Int) -> CommentAttachment {
        switch kind {
        case .image:
            return CommentAttachment(
                kind: .image,
                url: URL(string: "https://picsum.photos/seed/\(UUID().uuidString.prefix(4))/200/150")!,
                sizeBytes: size
            )
        case .video:
            return CommentAttachment(kind: .video, fileName: "clip.mp4", sizeBytes: size)
        case .file:
            return CommentAttachment(kind: .file, fileName: "file-\(pendingAttachments.count + 1).pdf", sizeBytes: size)
        }
    }

    private func iconName(for kind: CommentAttachmentKind) -> String {
        switch kind {
        case .image: return "photo"
        case .video: return "video"
        case .file: return "doc"
        }
    }
}
