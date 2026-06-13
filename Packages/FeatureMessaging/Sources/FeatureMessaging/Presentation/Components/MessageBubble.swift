import SwiftUI
import DesignSystem
import SplickDomain

struct MessageBubble: View {
    let message: ChatMessage
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 60) }
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .font(SplickTheme.Typography.body)
                    .foregroundStyle(isOutgoing ? .white : SplickTheme.Colors.textPrimary)
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                    .background(
                        isOutgoing
                            ? LinearGradient(
                                colors: [SplickTheme.Colors.primaryGradientStart, SplickTheme.Colors.primaryGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [SplickTheme.Colors.secondaryBackground, SplickTheme.Colors.secondaryBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: isOutgoing ? 16 : 4,
                            bottomTrailingRadius: isOutgoing ? 4 : 16,
                            topTrailingRadius: 16
                        )
                    )

                Text(message.createdAt.formatted(.dateTime.hour().minute()))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            if !isOutgoing { Spacer(minLength: 60) }
        }
    }
}
