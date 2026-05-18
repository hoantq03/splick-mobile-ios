import SwiftUI
import DesignSystem
import SplickDomain

public struct UserProfileView: View {
    public let user: UserSummary

    @Environment(\.dismiss) private var dismiss

    public init(user: UserSummary) {
        self.user = user
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                AvatarView(
                    imageURL: user.avatarURL,
                    name: user.displayName,
                    size: .large
                )
                .padding(.top, SplickTheme.Spacing.xl)

                VStack(spacing: SplickTheme.Spacing.xxs) {
                    Text(user.displayName)
                        .font(SplickTheme.Typography.largeTitle)
                    Text("@\(user.username)")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                HStack(spacing: SplickTheme.Spacing.xl) {
                    statBlock(value: "128", label: "Bạn bè")
                    statBlock(value: "42", label: "Bài viết")
                    statBlock(value: "15", label: "Nhóm")
                }
                .padding(.top, SplickTheme.Spacing.md)

                Spacer()

                SplickButton("Nhắn tin", style: .secondary) {}
                    .padding(.horizontal, SplickTheme.Spacing.xl)
                SplickButton("Thêm bạn") {}
                    .padding(.horizontal, SplickTheme.Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SplickTheme.Typography.title)
            Text(label)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
    }
}
