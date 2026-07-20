import SwiftUI
import DesignSystem
import Localization
import SplickDomain

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

                MentionTextField(
                    languageService.text(.feedBillReminderMessageLabel),
                    text: $message,
                    fontSize: 15,
                    minHeight: 88
                )
                .padding(SplickTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                        .fill(SplickTheme.Colors.tertiaryBackground)
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

                MentionTextField(
                    languageService.text(.feedBillReminderMessageLabel),
                    text: $message,
                    fontSize: 15,
                    minHeight: 88
                )
                .padding(SplickTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                        .fill(SplickTheme.Colors.tertiaryBackground)
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
