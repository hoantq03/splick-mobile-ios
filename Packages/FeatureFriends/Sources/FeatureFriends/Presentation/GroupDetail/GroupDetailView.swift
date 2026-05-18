import SwiftUI
import DesignSystem
import SplickDomain

struct GroupDetailView: View {
    let group: SplickDomain.Group
    let onUserTap: (UserSummary) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                headerCard

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    Text("Thành viên (\(group.memberCount))")
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)

                    LazyVStack(spacing: SplickTheme.Spacing.xs) {
                        ForEach(group.members) { member in
                            Button {
                                onUserTap(member)
                            } label: {
                                memberRow(member)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(SplickTheme.Spacing.md)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 52, height: 52)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                    Text(group.name)
                        .font(SplickTheme.Typography.title)
                    Text("\(group.memberCount) thành viên")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }

            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            HStack {
                Text("Mã mời: \(group.inviteCode)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                Spacer()
            }
        }
        .splickCard()
    }

    private func memberRow(_ user: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(user.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(user.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
