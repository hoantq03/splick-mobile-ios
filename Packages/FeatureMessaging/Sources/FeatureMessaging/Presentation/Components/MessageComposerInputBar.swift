import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain
import FeatureStickers

struct MessageComposerInputBar: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @Environment(\.currentUserSummary) private var currentUserSummary

    @Environment(\.messagingGifPickerFactory) private var messagingGifPickerFactory
    @Environment(\.gifKeywordSuggestFactory) private var gifKeywordSuggestFactory

    @Binding var text: String
    @Binding var attachmentDrafts: [CommentAttachmentDraft]
    var replyDraft: MessageReplyDraft?
    var onCancelReply: (() -> Void)?
    var onRevealReplyOriginal: (() -> Void)? = nil
    var editDraft: MessageEditDraft? = nil
    var onCancelEdit: (() -> Void)? = nil
    var placeholder: String
    var isSending: Bool
    var errorMessage: String?
    var onSend: (String, [CommentSubmissionAttachment]) -> Void
    @FocusState.Binding var isFocused: Bool

    @State private var validationMessage: String?
    @State private var gifPickerViewModel: GifPickerViewModel?
    @State private var showAttachmentPicker = false
    @State private var showEmojiInsertPicker = false
    @State private var showCustomEmojiUpload = false
    @State private var gifSuggest: GifKeywordSuggestController?

    private var currentUserId: UUID? { currentUserSummary?.id }

    private var composerConfiguration: AttachmentComposerConfiguration {
        AttachmentComposerConfiguration(
            maxImages: MessageImageLimits.maxImages,
            photoIconSize: 18,
            composerHeight: 36,
            actionButtonSize: 36,
            actionSpacing: 10,
            collapsesSendWhenEmpty: true
        )
    }

    private var displayedError: String? {
        validationMessage ?? errorMessage
    }

    private static let fadeTail: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: Self.fadeTail)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if let replyDraft, let onCancelReply {
                MessageReplyBanner(
                    draft: replyDraft,
                    onCancel: onCancelReply,
                    onRevealOriginal: onRevealReplyOriginal
                )
                    .transition(.replyIsland)
                    .zIndex(1)
            } else if editDraft != nil, let onCancelEdit {
                MessageEditBanner(onCancel: onCancelEdit)
                    .transition(.replyIsland)
                    .zIndex(1)
            }

            VStack(spacing: SplickTheme.Spacing.xxs) {
                if let gifSuggest {
                    GifKeywordSuggestStrip(
                        controller: gifSuggest,
                        mentionActive: false,
                        onSelect: { sticker in
                            sendGifImmediately(sticker)
                        },
                        onSeeMore: { query in
                            presentAttachmentPicker(prefilledQuery: query)
                        }
                    )
                    .padding(.horizontal, SplickTheme.Spacing.md)
                }

                AttachmentComposerView(
                text: $text,
                attachmentDrafts: $attachmentDrafts,
                validationMessage: Binding(
                    get: { displayedError },
                    set: { validationMessage = $0 }
                ),
                isFocused: Binding(
                    get: { isFocused },
                    set: { isFocused = $0 }
                ),
                configuration: composerConfiguration,
                isExternallyDisabled: isSending,
                onSend: onSend,
                textField: {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .font(SplickTheme.Typography.body)
                        .focused($isFocused)
                        .splickDisableWritingTools()
                        .padding(.horizontal, SplickTheme.Spacing.sm)
                        .padding(.vertical, SplickTheme.Spacing.xs)
                        .background(SplickTheme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        // Do not animate the focused field on canSend — layout springs
                        // resign first responder and bounce the keyboard on every send.
                        .accessibilityIdentifier(KeyboardDismissExempt.accessibilityIdentifier)
                        .onChange(of: text) { newValue in
                            gifSuggest?.onDraftChanged(newValue, mentionActive: false)
                        }
                },
                accessoryAfterPhoto: {
                    emojiMenuButton
                },
                sendButton: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .frame(width: 36, height: 36)
                        .accessibilityIdentifier(KeyboardDismissExempt.accessibilityIdentifier)
                }
            )
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            }
            .background(SplickTheme.Colors.background)
        }
        .background {
            LinearGradient(
                stops: SplickScrollChromeFadeMetrics.backgroundStops,
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .animation(MessageReplyIslandMotion.present, value: replyDraft?.messageId)
        .onAppear {
            if gifSuggest == nil {
                gifSuggest = gifKeywordSuggestFactory?()
            }
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
            presentAttachmentPicker(prefilledQuery: nil)
        } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(SplickTheme.Colors.secondaryBackground)
                }
        }
        .buttonStyle(.plain)
    }

    private var canSend: Bool {
        guard !isSending else { return false }
        guard !attachmentDrafts.contains(where: { $0.phase == .loading }) else { return false }
        guard !attachmentDrafts.contains(where: {
            if case .failed = $0.phase { return true }
            return false
        }) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasReadyAttachments = attachmentDrafts.contains { $0.phase == .ready && $0.submission != nil }
        return !trimmed.isEmpty || hasReadyAttachments
    }

    private func presentAttachmentPicker(prefilledQuery: String? = nil) {
        if gifPickerViewModel == nil {
            gifPickerViewModel = messagingGifPickerFactory?()
            guard gifPickerViewModel != nil else {
                showEmojiInsertPicker = true
                return
            }
            DispatchQueue.main.async {
                if let prefilledQuery {
                    gifPickerViewModel?.applyExternalSearch(prefilledQuery)
                }
                showAttachmentPicker = true
            }
            return
        }
        if let prefilledQuery {
            gifPickerViewModel?.applyExternalSearch(prefilledQuery)
        }
        showAttachmentPicker = true
    }

    private func openCustomEmojiUpload() {
        showEmojiInsertPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showCustomEmojiUpload = true
        }
    }

    private func insertEmoji(_ emoji: String) {
        let token = EmojiKind.from(emoji).storageValue
        if text.isEmpty || text.last?.isWhitespace == true {
            text += token
        } else {
            text += " \(token)"
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
        let messageText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        onSend(messageText, [submission])
    }
}
