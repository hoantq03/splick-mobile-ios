import SwiftUI
import DesignSystem
import SplickDomain

struct GroupRowView: View {
    let group: SplickDomain.Group

    private var subtitle: String {
        let count = "\(group.memberCount) thành viên"
        if group.inviteCode.isEmpty {
            return count
        }
        return "\(count) · @\(group.inviteCode)"
    }

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "person.3.fill")
                .font(.title3)
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 44, height: 44)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(group.name)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
