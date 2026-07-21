import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain
import FeatureStickers

enum BillReminderMessages {
    static let keys: [L10nKey] = [
        .feedBillReminderSuggest1,
        .feedBillReminderSuggest2,
        .feedBillReminderSuggest3,
        .feedBillReminderSuggest4,
        .feedBillReminderSuggest5,
    ]

    @MainActor
    static func random(using languageService: LanguageService) -> String {
        let key = keys.randomElement() ?? .feedBillReminderSuggest1
        return languageService.text(key)
    }
}

struct BillReminderSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    let user: UserSummary
    @Binding var message: String
    @Binding var selectedGIF: Sticker?
    let gifPickerViewModel: GifPickerViewModel?
    let onUserTap: ((UserSummary) -> Void)?
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                Button {
                    dismiss()
                    onUserTap?(user)
                } label: {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        AvatarView(
                            imageURL: user.avatarURL,
                            name: user.displayName,
                            size: .medium
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(SplickTheme.Typography.headline)
                            Text("@\(user.username)")
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                ReminderMessageEditor(
                    message: $message,
                    selectedGIF: $selectedGIF,
                    gifPickerViewModel: gifPickerViewModel
                )

                Button {
                    message = BillReminderMessages.random(using: languageService)
                } label: {
                    Label(languageService.text(.feedBillReminderSuggestAnother), systemImage: "dice")
                        .font(SplickTheme.Typography.callout)
                }

                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle(languageService.text(.feedBillRemindTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.feedPaymentEvidenceSubmit)) {
                        onSend()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct BillReminderAllSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    let users: [UserSummary]
    @Binding var message: String
    @Binding var selectedGIF: Sticker?
    let gifPickerViewModel: GifPickerViewModel?
    let onUserTap: ((UserSummary) -> Void)?
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                Text(languageService.format(.feedBillRemindAllMessage, users.count))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        ForEach(users) { user in
                            Button {
                                dismiss()
                                onUserTap?(user)
                            } label: {
                                VStack(spacing: 4) {
                                    AvatarView(
                                        imageURL: user.avatarURL,
                                        name: user.displayName,
                                        size: .small
                                    )
                                    Text(user.displayName)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                        .frame(width: 56)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ReminderMessageEditor(
                    message: $message,
                    selectedGIF: $selectedGIF,
                    gifPickerViewModel: gifPickerViewModel
                )

                Button {
                    message = BillReminderMessages.random(using: languageService)
                } label: {
                    Label(languageService.text(.feedBillReminderSuggestAnother), systemImage: "dice")
                        .font(SplickTheme.Typography.callout)
                }

                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle(languageService.text(.feedBillRemindAllTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.feedPaymentEvidenceSubmit)) {
                        onSend()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ReminderMessageEditor: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies

    @Binding var message: String
    @Binding var selectedGIF: Sticker?
    let gifPickerViewModel: GifPickerViewModel?

    @State private var showAttachmentPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            if let selectedGIF {
                ZStack(alignment: .topTrailing) {
                    InlineGifAttachmentView(
                        url: selectedGIF.url,
                        widthFraction: 0.42,
                        cornerRadius: SplickTheme.CornerRadius.inset
                    )
                    .frame(maxWidth: 180)

                    Button {
                        self.selectedGIF = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(.black.opacity(0.6), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }

            HStack(alignment: .bottom, spacing: SplickTheme.Spacing.xs) {
                MentionTextField(
                    languageService.text(.feedBillReminderMessageLabel),
                    text: $message,
                    fontSize: 15,
                    minHeight: 72
                )

                Button {
                    showAttachmentPicker = true
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .frame(width: 38, height: 38)
                        .background(SplickTheme.Colors.secondaryBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(languageService.text(.stickersEmoji))
            }
        }
        .padding(SplickTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .fill(SplickTheme.Colors.tertiaryBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .sheet(isPresented: $showAttachmentPicker) {
            if let gifPickerViewModel {
                AttachmentPickerView(
                    viewModel: gifPickerViewModel,
                    currentUserId: currentUserSummary?.id,
                    onSelectGif: { sticker in
                        selectedGIF = sticker
                        showAttachmentPicker = false
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            } else {
                EmojiPickerSheet(
                    currentUserId: currentUserSummary?.id,
                    mode: .inlineInsert,
                    onPick: { emoji in
                        insertEmoji(emoji)
                        showAttachmentPicker = false
                    },
                    onOpenUpload: {}
                )
            }
        }
    }

    private func insertEmoji(_ emoji: String) {
        let token = EmojiKind.from(emoji).storageValue
        if message.isEmpty || message.last?.isWhitespace == true {
            message += token
        } else {
            message += " \(token)"
        }
    }
}
