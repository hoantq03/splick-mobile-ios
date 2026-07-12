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

    @Environment(\.messagingGifPickerFactory) private var messagingGifPickerFactory

    @Binding var text: String
    @Binding var attachmentDrafts: [CommentAttachmentDraft]
    var replyDraft: MessageReplyDraft?
    var onCancelReply: (() -> Void)?
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

    private var composerConfiguration: AttachmentComposerConfiguration {
        AttachmentComposerConfiguration(
            maxImages: MessageImageLimits.maxImages,
            photoIconSize: 22,
            composerHeight: 36
        )
    }

    private var displayedError: String? {
        validationMessage ?? errorMessage
    }

    var body: some View {
        VStack(spacing: 0) {
            if let replyDraft, let onCancelReply {
                MessageReplyBanner(draft: replyDraft, onCancel: onCancelReply)
            }

            VStack(spacing: SplickTheme.Spacing.xxs) {
                AttachmentComposerView(
                text: $text,
                attachmentDrafts: $attachmentDrafts,
                validationMessage: Binding(
                    get: { displayedError },
                    set: { validationMessage = $0 }
                ),
                isFocused: .constant(false),
                configuration: composerConfiguration,
                isExternallyDisabled: isSending,
                onSend: onSend,
                textField: {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .font(SplickTheme.Typography.body)
                        .focused($isFocused)
                        .padding(.horizontal, SplickTheme.Spacing.sm)
                        .padding(.vertical, SplickTheme.Spacing.xs)
                        .background(SplickTheme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                },
                accessoryAfterPhoto: {
                    emojiMenuButton
                },
                sendButton: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            canSend
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.textTertiary
                        )
                }
            )
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            }
        }
        .background(SplickTheme.Colors.background)
        .onAppear {
            if gifPickerViewModel == nil {
                gifPickerViewModel = messagingGifPickerFactory?()
            }
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
                        appendGifSticker(sticker)
                        showAttachmentPicker = false
                    },
                    onSelectEmoji: { emoji in
                        insertEmoji(emoji)
                        showAttachmentPicker = false
                    }
                )
                .environmentObject(languageService)
                .environmentObject(emojiStore)
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
                    .font(.system(size: 22))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 32, height: 32)
            }
        } else {
            Button {
                showEmojiInsertPicker = true
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 22))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 32, height: 32)
            }
        }
    }

    private var remainingGifSlots: Int {
        let gifCount = attachmentDrafts.filter { $0.kind == .gif }.count
        return Swift.max(0, CommentAttachmentValidator.maxGifs - gifCount)
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

    private func appendGifSticker(_ sticker: Sticker) {
        let submission = CommentSubmissionAttachment(
            kind: .gif,
            remoteURL: sticker.url,
            fileName: "gif-\(sticker.id).gif"
        )
        if let error = CommentAttachmentValidator.canAdd(
            CommentAttachment(kind: .gif, fileName: submission.fileName),
            to: CommentAttachmentValidator.previewModels(
                from: AttachmentDraftImporter.readySubmissions(from: attachmentDrafts)
            )
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
}
