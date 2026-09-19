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
    @Environment(\.currentUserSummary) private var currentUserSummary

    let placeholder: String
    /// When set (e.g. user tapped Reply), pre-fills a durable mention token for the author.
    let prefillMentionUser: UserSummary?
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
    @State private var mentionDisplayNamesByKey: [String: String] = [:]
    @State private var mentionDisplayNamesByUserId: [UUID: String] = [:]
    @State private var showAttachmentPicker = false
    @State private var showEmojiInsertPicker = false
    @State private var showCustomEmojiUpload = false

    private enum Layout {
        static let fieldHeight: CGFloat = 44
        static let actionButtonSize: CGFloat = 44
        static let photoIconSize: CGFloat = 20
        static let emojiIconSize: CGFloat = 22
        static let sendIconSize: CGFloat = 20
        static let fieldCornerRadius: CGFloat = 22
    }

    private var currentUserId: UUID? { currentUserSummary?.id }

    private var composerConfiguration: AttachmentComposerConfiguration {
        AttachmentComposerConfiguration(
            photoIconSize: Layout.photoIconSize,
            composerHeight: Layout.fieldHeight,
            actionButtonSize: Layout.actionButtonSize,
            actionSpacing: 10
        )
    }

    init(
        placeholder: String,
        prefillMentionUser: UserSummary? = nil,
        isFocused: Binding<Bool> = .constant(false),
        groupId: UUID? = nil,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        gifPickerViewModel: GifPickerViewModel? = nil,
        onSubmit: @escaping (String, [CommentSubmissionAttachment]) -> Void
    ) {
        self.placeholder = placeholder
        self.prefillMentionUser = prefillMentionUser
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
                configuration: composerConfiguration,
                onSend: onSubmit,
                textField: {
                    MentionTextField(
                        placeholder,
                        text: $draft,
                        isFocused: $isFocused,
                        fontSize: 14,
                        minHeight: Layout.fieldHeight,
                        displayNamesByUsername: mentionDisplayNamesByKey,
                        displayNamesByUserId: mentionDisplayNamesByUserId
                    )
                    .background(
                        RoundedRectangle(cornerRadius: Layout.fieldCornerRadius)
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
                        .font(.system(size: Layout.sendIconSize, weight: .semibold))
                        .frame(width: Layout.actionButtonSize, height: Layout.actionButtonSize)
                        .background {
                            Circle()
                                .fill(SplickTheme.Colors.secondaryBackground)
                        }
                }
            )
        }
        .onChange(of: mentionViewModel?.friends.map(\.id)) { _ in
            mentionViewModel?.friends.forEach { registerMentionDisplayName(for: $0) }
        }
        .onChange(of: prefillMentionUser?.id) { _ in
            applyPrefillMention(prefillMentionUser)
        }
        .onAppear {
            applyPrefillMention(prefillMentionUser)
        }
        .sheet(isPresented: $showEmojiInsertPicker) {
            EmojiPickerSheet(
                currentUserId: currentUserId,
                mode: .inlineInsert,
                onPick: { emoji in insertEmoji(emoji) },
                onOpenUpload: { openCustomEmojiUpload() }
            )
        }
        .sheet(isPresented: $showCustomEmojiUpload) {
            if let deps = customEmojiDependencies {
                CustomEmojiUploadSheet(
                    currentUserId: currentUserId,
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
                    currentUserId: currentUserId,
                    onSelectGif: { sticker in
                        showAttachmentPicker = false
                        sendGifImmediately(sticker)
                    },
                    onSelectEmoji: { emoji in
                        insertEmoji(emoji)
                        showAttachmentPicker = false
                    }
                )
                .environmentObject(languageService)
                .environmentObject(emojiStore)
                .environment(\.currentUserSummary, currentUserSummary)
                .environment(\.customEmojiDependencies, customEmojiDependencies)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var emojiMenuButton: some View {
        Button {
            if gifPickerViewModel != nil {
                showAttachmentPicker = true
            } else {
                showEmojiInsertPicker = true
            }
        } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: Layout.emojiIconSize, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: Layout.actionButtonSize, height: Layout.actionButtonSize)
                .background {
                    Circle()
                        .fill(SplickTheme.Colors.secondaryBackground)
                }
        }
        .buttonStyle(.plain)
    }

    private func openCustomEmojiUpload() {
        showEmojiInsertPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showCustomEmojiUpload = true
        }
    }

    private func applyPrefillMention(_ user: UserSummary?) {
        guard let user else {
            appliedPrefillUsername = nil
            return
        }
        registerMentionDisplayName(for: user)
        let mention = "\(MentionContext.token(for: user.id)) "
        appliedPrefillUsername = user.username
        guard draft != mention else { return }
        draft = mention
        syncMentionPicker(with: draft)
    }

    private func registerMentionDisplayName(for user: UserSummary) {
        let trimmed = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = trimmed.isEmpty ? user.username : trimmed
        mentionDisplayNamesByKey[user.username.lowercased()] = display
        mentionDisplayNamesByKey[user.id.uuidString.lowercased()] = display
        mentionDisplayNamesByUserId[user.id] = display
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
            if openingPicker {
                withAnimation(.easeOut(duration: 0.18)) {
                    showMentionPicker = true
                }
            } else {
                showMentionPicker = true
            }
            if openingPicker || context.query != activeMentionQuery {
                activeMentionQuery = context.query
                mentionViewModel?.reset(query: context.query)
            }
            mentionViewModel?.friends.forEach { registerMentionDisplayName(for: $0) }
        } else if showMentionPicker {
            withAnimation(.easeOut(duration: 0.18)) {
                showMentionPicker = false
            }
            activeMentionQuery = ""
        } else {
            activeMentionQuery = ""
        }
    }

    private func insertMention(_ user: UserSummary) {
        registerMentionDisplayName(for: user)
        guard MentionContext.insertMention(userId: user.id, in: &draft) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            showMentionPicker = false
        }
        activeMentionQuery = ""
        isFocused = true
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
