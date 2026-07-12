import SwiftUI
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
    @State private var attachmentDrafts: [CommentAttachmentDraft] = []
    @State private var validationMessage: String?
    @State private var showMentionPicker = false
    @State private var activeMentionQuery = ""
    @State private var mentionViewModel: MentionFriendsViewModel?
    @State private var showAttachmentPicker = false
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
            if showMentionPicker, let mentionViewModel {
                MentionPickerPopup(viewModel: mentionViewModel) { user in
                    insertMention(user)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            AttachmentComposerView(
                text: $draft,
                attachmentDrafts: $attachmentDrafts,
                validationMessage: $validationMessage,
                isFocused: $isFocused,
                onSend: onSubmit,
                textField: {
                    MentionTextField(
                        placeholder,
                        text: $draft,
                        isFocused: $isFocused,
                        fontSize: 13,
                        minHeight: composerHeight
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    )
                    .onChange(of: draft) { newValue in
                        syncMentionPicker(with: newValue)
                    }
                },
                accessoryAfterPhoto: {
                    emojiMenuButton
                },
                sendButton: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            canSubmit
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.textTertiary
                        )
                        .frame(width: composerHeight, height: composerHeight)
                }
            )
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
        .sheet(isPresented: $showAttachmentPicker) {
            if let gifPickerViewModel {
                AttachmentPickerView(
                    viewModel: gifPickerViewModel,
                    onSelectGif: { sticker in
                        showAttachmentPicker = false
                        sendGifImmediately(sticker)
                    },
                    onSelectEmoji: { emoji in
                        insertEmoji(emoji)
                        showAttachmentPicker = false
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var emojiMenuButton: some View {
        if gifPickerViewModel != nil {
            Button {
                showAttachmentPicker = true
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

    private var canSubmit: Bool {
        guard !attachmentDrafts.contains(where: { $0.phase == .loading }) else { return false }
        guard !attachmentDrafts.contains(where: {
            if case .failed = $0.phase { return true }
            return false
        }) else { return false }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasReadyAttachments = attachmentDrafts.contains { $0.phase == .ready && $0.submission != nil }
        return !trimmed.isEmpty || hasReadyAttachments
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

    /// Tap-to-send: GIF goes out immediately (multi-select stays photo/video only).
    private func sendGifImmediately(_ sticker: Sticker) {
        let submission = CommentSubmissionAttachment(
            kind: .gif,
            remoteURL: sticker.url,
            fileName: "gif-\(sticker.id).gif"
        )
        validationMessage = nil
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        onSubmit(text, [submission])
    }
}
