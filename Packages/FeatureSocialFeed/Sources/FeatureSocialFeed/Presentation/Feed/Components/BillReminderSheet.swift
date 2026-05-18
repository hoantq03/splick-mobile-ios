import SwiftUI
import DesignSystem
import SplickDomain

enum BillReminderMessages {
    static let defaults = [
        "Bạn ơi, nhớ chuyển phần bill của bạn nhé! 🙏",
        "Nhắc nhẹ: bill hôm nay chưa thấy bạn thanh toán đâu 😅",
        "Hello! Giúp mình settle bill nha, cảm ơn bạn!",
        "Bill đang chờ bạn — chuyển khi rảnh giúp mình nhé!",
        "Team ơi, ai chưa chuyển bill nhớ làm giúp mình nha!",
    ]

    static func random() -> String {
        defaults.randomElement() ?? defaults[0]
    }
}

struct BillReminderSheet: View {
    let user: UserSummary
    @Binding var message: String
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
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
                }

                TextField("Lời nhắn", text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .font(SplickTheme.Typography.body)
                    .padding(SplickTheme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    )

                Button {
                    message = BillReminderMessages.random()
                } label: {
                    Label("Gợi ý lời nhắn khác", systemImage: "dice")
                        .font(SplickTheme.Typography.callout)
                }

                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle("Nhắc nhở")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gửi") {
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
    let users: [UserSummary]
    @Binding var message: String
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                Text("Gửi nhắc tới \(users.count) người chưa thanh toán")
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        ForEach(users) { user in
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
                    }
                }

                TextField("Lời nhắn", text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .font(SplickTheme.Typography.body)
                    .padding(SplickTheme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    )

                Button {
                    message = BillReminderMessages.random()
                } label: {
                    Label("Gợi ý lời nhắn khác", systemImage: "dice")
                        .font(SplickTheme.Typography.callout)
                }

                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle("Nhắc tất cả")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gửi") {
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
