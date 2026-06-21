import SwiftUI

public struct ProfileSettingsItem: Identifiable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let subtitle: String?
    public let isDestructive: Bool
    public let action: () -> Void

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
}

public struct ProfileSettingsGroup: View {
    private let title: String
    private let items: [ProfileSettingsItem]

    public init(title: String, items: [ProfileSettingsItem]) {
        self.title = title
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(title)
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.leading, SplickTheme.Spacing.sm)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ProfileSettingsRow(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        isDestructive: item.isDestructive,
                        action: item.action
                    )

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, SplickTheme.Spacing.xl + SplickTheme.Spacing.sm)
                    }
                }
            }
            .background(SplickTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control))
        }
    }
}

public struct ProfileSettingsRow: View {
    private let icon: String
    private let title: String
    private let subtitle: String?
    private let isDestructive: Bool
    private let action: () -> Void

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isDestructive ? SplickTheme.Colors.error : SplickTheme.Colors.primary)
                    .frame(width: 24)

                Text(title)
                    .font(SplickTheme.Typography.body)
                    .foregroundStyle(isDestructive ? SplickTheme.Colors.error : SplickTheme.Colors.textPrimary)

                Spacer(minLength: 0)

                if let subtitle {
                    Text(subtitle)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
